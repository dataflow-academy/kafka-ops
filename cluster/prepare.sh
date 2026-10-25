#!/usr/bin/env bash
# Start state "cluster installed": Strimzi operator plus a three-node Kafka
# cluster (3 controllers, 3 brokers), Ready. Run it on node1. Idempotent.
#
# The operator is the release file of Strimzi 1.1.0, downloaded like Strimzi's own documentation does it and
# checked against its sha256; kafka.yaml names the Kafka version itself.
. "$(dirname "$0")/../lib/common.sh"
need kubectl; need curl
kube_ready || die "kubectl cannot reach the cluster. Run k3s/prepare.sh first."

STRIMZI_URL="https://github.com/strimzi/strimzi-kafka-operator/releases/download/1.1.0/strimzi-cluster-operator-1.1.0.yaml"
STRIMZI_SHA256=ee7e38d61452fb7b3be08a3b0fb4497ee0e38d50eb38f41fa4c2276078f68fd0
file="$HOME/strimzi-1.1.0.yaml"

log "Namespace ${KAFKA_NAMESPACE}"
kubectl create namespace "$KAFKA_NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -

log "Strimzi 1.1.0"
curl -sfL "$STRIMZI_URL" -o "$file" || die "Download failed: $STRIMZI_URL"
echo "$STRIMZI_SHA256  $file" | sha256sum -c --status || die "Checksum mismatch for $STRIMZI_URL"
# The release file is written for the namespace "myproject".
sed -i "s/namespace: .*/namespace: ${KAFKA_NAMESPACE}/" "$file"
kubectl apply -f "$file" >/dev/null
kubectl -n "$KAFKA_NAMESPACE" rollout status deployment/strimzi-cluster-operator --timeout=180s

log "Kafka cluster ${KAFKA_CLUSTER}"
kubectl -n "$KAFKA_NAMESPACE" apply -f "$(dirname "$0")/metrics-config.yaml"
kubectl apply -f "$(dirname "$0")/kafka.yaml"
kubectl -n "$KAFKA_NAMESPACE" wait "kafka/${KAFKA_CLUSTER}" --for=condition=Ready --timeout=600s

# The self-check tests of the labs run as `ssh ... python3 tests.py` and find
# the cluster through this file (see tests.py.erb in the labs repo).
kubectl -n "$KAFKA_NAMESPACE" get kafka "$KAFKA_CLUSTER" \
  -o jsonpath='{.status.listeners[?(@.name=="external")].bootstrapServers}' > "$HOME/.kafka-bootstrap-servers"
echo >> "$HOME/.kafka-bootstrap-servers"

log "Done"
kubectl -n "$KAFKA_NAMESPACE" get kafka,kafkanodepool,pods
