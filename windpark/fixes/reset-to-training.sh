#!/usr/bin/env bash
# Start state for the lab "Helping the dev teams": cluster, monitoring and the wind park with faults F1-F5, topic
# auto-creation on, and one poison pill from the maintenance tool already in the telemetry topic. Idempotent.
. "$(dirname "$0")/../../lib/common.sh"
need kubectl
kube_ready || die "kubectl cannot reach the cluster. Run k3s/prepare.sh first."
NS="$KAFKA_NAMESPACE"
kubectl -n "$NS" get kafka "$KAFKA_CLUSTER" >/dev/null 2>&1 || "$ROOT/cluster/prepare.sh"
kubectl -n "$NS" get deploy prometheus >/dev/null 2>&1 || "$ROOT/monitoring/prepare.sh"
"$ROOT/tools/prepare.sh"
[ -x "$ROOT/governance/reset.sh" ] && "$ROOT/governance/reset.sh" >/dev/null
"$ROOT/windpark/prepare.sh"
# The maintenance tool writes its pill only every 20 minutes; do not wait for it.
kubectl -n windpark create job --from=cronjob/maintenance-report "maintenance-start-$(date +%s)" >/dev/null
log "Wind park with faults ready"
