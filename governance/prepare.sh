#!/usr/bin/env bash
# Start state for the governance lab: cluster, monitoring and wind park as they are after "Helping the dev teams"
# (faults F1, F2, F4, F5 repaired, F3 still there), topic auto-creation still on, no policies. Idempotent. Run it on node1.
. "$(dirname "$0")/../lib/common.sh"
need kubectl
kube_ready || die "kubectl cannot reach the cluster. Run k3s/prepare.sh first."
NS="$KAFKA_NAMESPACE"
kubectl -n "$NS" get kafka "$KAFKA_CLUSTER" >/dev/null 2>&1 || "$ROOT/cluster/prepare.sh"
kubectl -n "$NS" get deploy prometheus >/dev/null 2>&1 || "$ROOT/monitoring/prepare.sh"
"$ROOT/tools/prepare.sh"
"$(dirname "$0")/reset.sh" >/dev/null   # no policies, auto-creation on
"$ROOT/windpark/fixes/after-helping-devs.sh"
log "Governance lab ready"
