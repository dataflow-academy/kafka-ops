#!/usr/bin/env bash
# Start state for the multi-cluster lab: only the first cluster (open: no authorization, or authorization from the
# security lab with allow.everyone.if.no.acl.found and no ACLs), the wind park running without faults on the plain
# listener, no second cluster. Anything left from an earlier run is removed (reset.sh). Run it on node1.
. "$(dirname "$0")/../lib/common.sh"
need kubectl
kube_ready || die "kubectl cannot reach the cluster."
kubectl -n "$KAFKA_NAMESPACE" get kafka "$KAFKA_CLUSTER" >/dev/null 2>&1 || die "Kafka cluster is missing. Run cluster/prepare.sh first."
HERE="$(cd "$(dirname "$0")/.." && pwd)"
# Users and ACLs of the security lab go, the applications return to the plain listener (MirrorMaker 2 and the move
# of the control room work without certificates).
"$HERE/security/reset.sh" --keep-authorization
"$(dirname "$0")/reset.sh"
log "Done"
