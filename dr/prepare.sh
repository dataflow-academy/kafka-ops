#!/usr/bin/env bash
# Start state for the multi-cluster lab: only the first cluster (open, no authorization), the wind park running
# without faults, no second cluster. Anything left from an earlier run is removed (reset.sh). Run it on node1.
. "$(dirname "$0")/../lib/common.sh"
need kubectl
kube_ready || die "kubectl cannot reach the cluster."
kubectl -n "$KAFKA_NAMESPACE" get kafka "$KAFKA_CLUSTER" >/dev/null 2>&1 || die "Kafka cluster is missing. Run cluster/prepare.sh first."
HERE="$(cd "$(dirname "$0")/.." && pwd)"
if [ -n "$(kubectl -n "$KAFKA_NAMESPACE" get kafka "$KAFKA_CLUSTER" -o jsonpath='{.spec.kafka.authorization.type}')" ]; then
  "$HERE/security/reset.sh"
fi
"$(dirname "$0")/reset.sh"
log "Done"
