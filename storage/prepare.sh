#!/usr/bin/env bash
# Start state for the storage lab: cluster, monitoring and wind park running, the Kafka tools pod there, none of the
# experiment topics of this lab. Idempotent. Run it on node1.
. "$(dirname "$0")/../lib/common.sh"
need kubectl
kube_ready || die "kubectl cannot reach the cluster. Run k3s/prepare.sh first."
NS="$KAFKA_NAMESPACE"
kubectl -n "$NS" get kafka "$KAFKA_CLUSTER" >/dev/null 2>&1 || "$ROOT/cluster/prepare.sh"
kubectl -n "$NS" get deploy prometheus >/dev/null 2>&1 || "$ROOT/monitoring/prepare.sh"
kubectl get ns windpark >/dev/null 2>&1 || "$ROOT/windpark/prepare.sh"
"$ROOT/tools/prepare.sh"
"$(dirname "$0")/reset.sh" >/dev/null
log "Storage lab ready"
