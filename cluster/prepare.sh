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

"$(dirname "$0")/operator.sh"

log "Kafka ${KAFKA_VERSION}"
apply_tpl "$(dirname "$0")/kafka.yaml" -n "$KAFKA_NAMESPACE"
kubectl -n "$KAFKA_NAMESPACE" wait "kafka/${KAFKA_CLUSTER}" --for=condition=Ready --timeout=600s

# The self-check tests of the labs run as `ssh ... python3 tests.py` and find
# the cluster through this file (see tests.py.erb in the labs repo).
kubectl -n "$KAFKA_NAMESPACE" get kafka "$KAFKA_CLUSTER" \
  -o jsonpath='{.status.listeners[?(@.name=="external")].bootstrapServers}' > "$HOME/.kafka-bootstrap-servers"
echo >> "$HOME/.kafka-bootstrap-servers"

log "Done"
kubectl -n "$KAFKA_NAMESPACE" get kafka,kafkanodepool,pods
