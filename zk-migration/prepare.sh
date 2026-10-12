#!/usr/bin/env bash
# Start state for the ZooKeeper-to-KRaft lab: Strimzi 0.45 and a ZooKeeper-based Kafka cluster (three ZooKeeper
# nodes, three brokers, no node pools) with a producer writing 50 records per second. The versions are
# pinned in versions.env (STRIMZI_ZK_VERSION, KAFKA_ZK_VERSION).
#
# Everything that is there is removed first, including the CRDs: the Strimzi of this lab is older than the one of
# the other labs and does not know the v1 API. The wind park cannot run on it; reset.sh brings it back.
# Run it on node1. Idempotent: a cluster that is still pristine is left alone.
. "$(dirname "$0")/../lib/common.sh"
need kubectl; need envsubst
kube_ready || die "kubectl cannot reach the cluster."
HERE="$(cd "$(dirname "$0")/.." && pwd)"
N=(-n "$KAFKA_NAMESPACE")

pristine() {
  [ "$(kubectl "${N[@]}" get deployment strimzi-cluster-operator -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null | sed 's/.*://')" = "$STRIMZI_ZK_VERSION" ] \
    && [ -n "$(kubectl "${N[@]}" get kafka "$KAFKA_CLUSTER" -o jsonpath='{.spec.zookeeper.replicas}' 2>/dev/null)" ] \
    && [ -z "$(kubectl "${N[@]}" get kafkanodepool -o name 2>/dev/null)" ] \
    && [ -z "$(kubectl "${N[@]}" get kafka "$KAFKA_CLUSTER" -o jsonpath='{.metadata.annotations.strimzi\.io/kraft}' 2>/dev/null)" ]
}

if ! pristine; then
  log "Removing the current cluster and Strimzi"
  [ -x "$HERE/windpark/reset.sh" ] && "$HERE/windpark/reset.sh" || true
  kubectl "${N[@]}" delete kafkatopic,kafkauser --all --ignore-not-found --timeout=180s >/dev/null 2>&1 || true
  "$HERE/cluster/reset.sh"
  log "Strimzi ${STRIMZI_ZK_VERSION}"
  "$HERE/upgrade/operator.sh" "$STRIMZI_ZK_VERSION"
  # The default limit of 256 Mi is too small for this operator once node pools and the migration come in (OOMKilled).
  kubectl "${N[@]}" set resources deployment/strimzi-cluster-operator --limits=memory=768Mi --requests=memory=512Mi >/dev/null
  kubectl "${N[@]}" rollout status deployment/strimzi-cluster-operator --timeout=180s
  log "Kafka ${KAFKA_ZK_VERSION} with ZooKeeper"
  apply_tpl "$(dirname "$0")/zk-cluster.yaml" "${N[@]}"
fi
kubectl "${N[@]}" wait "kafka/${KAFKA_CLUSTER}" --for=condition=Ready --timeout=900s
apply_tpl "$(dirname "$0")/load.yaml" "${N[@]}"
kubectl "${N[@]}" wait kafkatopic/migration-demo --for=condition=Ready --timeout=120s
kubectl "${N[@]}" get kafka "$KAFKA_CLUSTER" -o jsonpath='{.status.kafkaVersion} {.status.kafkaMetadataState}{"\n"}'
# The self-checks find the cluster through this file.
kubectl "${N[@]}" get kafka "$KAFKA_CLUSTER" -o jsonpath='{.status.listeners[?(@.name=="external")].bootstrapServers}' > "$HOME/.kafka-bootstrap-servers"
echo >> "$HOME/.kafka-bootstrap-servers"
log "Done"
