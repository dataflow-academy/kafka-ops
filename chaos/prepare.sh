#!/usr/bin/env bash
# Start state for the failure lab: cluster, monitoring and wind park (with its faults) running, no failure
# active, the Kafka tools pod there, and the topic of team Alarme on the broker of node3 (place-alerts.sh). Idempotent. Run it on node1.
. "$(dirname "$0")/lib.sh"
need kubectl; need jq
kube_ready || die "kubectl cannot reach the cluster. Run k3s/prepare.sh first."
kubectl -n "$NS" get kafka "$KAFKA_CLUSTER" >/dev/null 2>&1 || "$ROOT/cluster/prepare.sh"
[ -x "$ROOT/monitoring/prepare.sh" ] && kubectl get deploy prometheus -n "$NS" >/dev/null 2>&1 || "$ROOT/monitoring/prepare.sh"
kubectl get ns windpark >/dev/null 2>&1 || "$ROOT/windpark/prepare.sh"
"$ROOT/tools/prepare.sh"
"$(dirname "$0")/heal.sh"
if kubectl get validatingadmissionpolicy kafkatopic-naming >/dev/null 2>&1; then
  log "The naming policy of the governance lab is active: the experiment topics (topics.yaml) would be rejected. Run governance/reset.sh first."
fi

"$(dirname "$0")/place-alerts.sh" || true   # only if the wind park topic exists
log "Failure lab ready"
