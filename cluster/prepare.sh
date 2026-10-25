#!/usr/bin/env bash
# Start state "cluster installed": Strimzi operator plus a three-node Kafka
# cluster (3 controllers, 3 brokers), Ready. Run it on node1. Idempotent.
#
# The operator comes from operator.sh (the release file of Strimzi 1.1.0, as in the
# first lab); kafka.yaml names the Kafka version itself.
. "$(dirname "$0")/../lib/common.sh"
need kubectl; need curl
kube_ready || die "kubectl cannot reach the cluster. Run k3s/prepare.sh first."

HERE="$(cd "$(dirname "$0")" && pwd)"
"$HERE/operator.sh"

# A leftover hello cluster would hold the NodePorts 31094-31097.
"$ROOT/hello/reset.sh" >/dev/null 2>&1 || true

log "Kafka cluster ${KAFKA_CLUSTER}"
kubectl apply -f "$HERE/kafka.yaml"
kubectl -n "$KAFKA_NAMESPACE" wait "kafka/${KAFKA_CLUSTER}" --for=condition=Ready --timeout=600s

# The working file of the later labs (they edit and apply it): the reference design, on the catch-up path too.
# cluster/nordwind-kafka.yaml (the file the groups edit in the design lab) on the catch-up path too. A design the
# group made itself (no TODO left in the file) is not touched.
if grep -q TODO "$HERE/nordwind-kafka.yaml"; then cp "$HERE/kafka.yaml" "$HERE/nordwind-kafka.yaml"; fi

# The pod with the Kafka command line tools for the places where the access from inside the cluster is the point.
"$HERE/../tools/prepare.sh"

# The self-check tests of the labs run as `ssh ... python3 tests.py` and find
# the cluster through this file (see tests.py.erb in the labs repo).
kubectl -n "$KAFKA_NAMESPACE" get kafka "$KAFKA_CLUSTER" \
  -o jsonpath='{.status.listeners[?(@.name=="external")].bootstrapServers}' > "$HOME/.kafka-bootstrap-servers"
echo >> "$HOME/.kafka-bootstrap-servers"

log "Done"
kubectl -n "$KAFKA_NAMESPACE" get kafka,kafkanodepool,pods
