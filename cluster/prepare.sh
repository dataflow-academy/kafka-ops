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

# The reference design as a file, so that later labs (monitoring) can edit and apply
# ~/nordwind-kafka.yaml on the catch-up path too. A design the group made itself is not touched.
cp "$HERE/kafka.yaml" "$HOME/nordwind-kafka-reference.yaml"
[ -e "$HOME/nordwind-kafka.yaml" ] || cp "$HOME/nordwind-kafka-reference.yaml" "$HOME/nordwind-kafka.yaml"

# The Kafka command line tools live in their own pod from the second lab on (tools/, owned by the
# day 2 material; present once that branch is merged).
[ -x "$HERE/../tools/prepare.sh" ] && "$HERE/../tools/prepare.sh"

# The self-check tests of the labs run as `ssh ... python3 tests.py` and find
# the cluster through this file (see tests.py.erb in the labs repo).
kubectl -n "$KAFKA_NAMESPACE" get kafka "$KAFKA_CLUSTER" \
  -o jsonpath='{.status.listeners[?(@.name=="external")].bootstrapServers}' > "$HOME/.kafka-bootstrap-servers"
echo >> "$HOME/.kafka-bootstrap-servers"

log "Done"
kubectl -n "$KAFKA_NAMESPACE" get kafka,kafkanodepool,pods
