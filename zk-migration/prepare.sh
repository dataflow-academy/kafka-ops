#!/usr/bin/env bash
# Start state for the ZooKeeper-to-KRaft lab: Strimzi 0.45 and a ZooKeeper-based Kafka cluster (three ZooKeeper
# nodes, three brokers, no node pools) with a producer writing 50 records per second: Strimzi 0.45.1, Kafka 3.9.1.
#
# Everything that is there is removed first, including the CRDs: the Strimzi of this lab is older than the one of
# the other labs and does not know the v1 API. The wind park cannot run on it; reset.sh brings it back.
# Run it on node1. Idempotent: a cluster that is still pristine is left alone.
. "$(dirname "$0")/../lib/common.sh"
need kubectl
kube_ready || die "kubectl cannot reach the cluster."
HERE="$(cd "$(dirname "$0")/.." && pwd)"
N=(-n "$KAFKA_NAMESPACE")

pristine() {
  [ "$(kubectl "${N[@]}" get deployment strimzi-cluster-operator -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null | sed 's/.*://')" = 0.45.1 ] \
    && [ -n "$(kubectl "${N[@]}" get kafka "$KAFKA_CLUSTER" -o jsonpath='{.spec.zookeeper.replicas}' 2>/dev/null)" ] \
    && [ -z "$(kubectl "${N[@]}" get kafkanodepool -o name 2>/dev/null)" ] \
    && [ -z "$(kubectl "${N[@]}" get kafka "$KAFKA_CLUSTER" -o jsonpath='{.metadata.annotations.strimzi\.io/kraft}' 2>/dev/null)" ]
}

if ! pristine; then
  log "Removing the current cluster and Strimzi"
  if [ -x "$HERE/windpark/reset.sh" ]; then "$HERE/windpark/reset.sh" || true; fi
  kubectl "${N[@]}" delete kafkatopic,kafkauser --all --ignore-not-found --timeout=180s >/dev/null 2>&1 || true
  "$HERE/cluster/reset.sh"
  log "Strimzi 0.45.1"
  "$HERE/cluster/operator.sh" 0.45.1
  # The default limit of 256 Mi is too small for this operator once node pools and the migration come in (OOMKilled).
  kubectl "${N[@]}" set resources deployment/strimzi-cluster-operator --limits=memory=768Mi --requests=memory=512Mi >/dev/null
  kubectl "${N[@]}" rollout status deployment/strimzi-cluster-operator --timeout=180s
  log "Kafka 3.9.1 with ZooKeeper"
  kubectl apply -f "$(dirname "$0")/zk-cluster.yaml"
fi
kubectl "${N[@]}" wait "kafka/${KAFKA_CLUSTER}" --for=condition=Ready --timeout=900s
kubectl apply -f "$(dirname "$0")/load.yaml"
kubectl "${N[@]}" wait kafkatopic/migration-demo --for=condition=Ready --timeout=120s
kubectl "${N[@]}" get kafka "$KAFKA_CLUSTER" -o jsonpath='{.status.kafkaVersion} {.status.kafkaMetadataState}{"\n"}'
# The self-checks find the cluster through this file.
kubectl "${N[@]}" get kafka "$KAFKA_CLUSTER" -o jsonpath='{.status.listeners[?(@.name=="external")].bootstrapServers}' > "$HOME/.kafka-bootstrap-servers"
echo >> "$HOME/.kafka-bootstrap-servers"
log "Done"
