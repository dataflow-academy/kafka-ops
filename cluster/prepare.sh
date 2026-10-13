#!/usr/bin/env bash
# Start state "cluster installed": Strimzi operator plus a three-node Kafka
# cluster (3 controllers, 3 brokers), Ready. Run it on node1. Idempotent.
#
# The operator install file is downloaded from the Strimzi release page with
# the version and checksum pinned in versions.env. That is the same flow as
# Strimzi's own documentation, so participants meet what they will meet in
# production; the checksum protects against a changed or truncated download.
. "$(dirname "$0")/../lib/common.sh"
need kubectl; need curl; need envsubst
kube_ready || die "kubectl cannot reach the cluster. Run k3s/prepare.sh first."

STRIMZI_URL="https://github.com/strimzi/strimzi-kafka-operator/releases/download/${STRIMZI_VERSION}/strimzi-cluster-operator-${STRIMZI_VERSION}.yaml"
sha_var="STRIMZI_INSTALL_SHA256_${STRIMZI_VERSION//./_}"

log "Namespace ${KAFKA_NAMESPACE}"
kubectl create namespace "$KAFKA_NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -

log "Strimzi ${STRIMZI_VERSION}"
tmp="$(mktemp)"; trap 'rm -f "$tmp"' EXIT
curl -sfL "$STRIMZI_URL" -o "$tmp" || die "Download failed: $STRIMZI_URL"
echo "${!sha_var}  $tmp" | sha256sum -c --status || die "Checksum mismatch for $STRIMZI_URL"
# The release file is written for the namespace "myproject".
sed "s/namespace: .*/namespace: ${KAFKA_NAMESPACE}/" "$tmp" | kubectl apply --server-side --force-conflicts -n "$KAFKA_NAMESPACE" -f - >/dev/null
kubectl -n "$KAFKA_NAMESPACE" rollout status deployment/strimzi-cluster-operator --timeout=180s

log "Kafka ${KAFKA_VERSION}"
kubectl -n "$KAFKA_NAMESPACE" apply -f "$(dirname "$0")/metrics-config.yaml"
apply_tpl "$(dirname "$0")/kafka.yaml" -n "$KAFKA_NAMESPACE"
kubectl -n "$KAFKA_NAMESPACE" wait "kafka/${KAFKA_CLUSTER}" --for=condition=Ready --timeout=600s

# The self-check tests of the labs run as `ssh ... python3 tests.py` and find
# the cluster through this file (see tests.py.erb in the labs repo).
kubectl -n "$KAFKA_NAMESPACE" get kafka "$KAFKA_CLUSTER" \
  -o jsonpath='{.status.listeners[?(@.name=="external")].bootstrapServers}' > "$HOME/.kafka-bootstrap-servers"
echo >> "$HOME/.kafka-bootstrap-servers"

log "Done"
kubectl -n "$KAFKA_NAMESPACE" get kafka,kafkanodepool,pods
