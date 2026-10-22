#!/usr/bin/env bash
# Start state "wind park running": the applications of the six teams in the namespace `windpark`,
# with the faults F1-F5 built in (see README). Needs the cluster (cluster/prepare.sh). Run it on node1.
# Idempotent.
#
#   ./prepare.sh                 faulty wind park (windpark.yaml); the topics of the onboarding requests are
#                                created as a careful platform team would (only if they do not exist yet)
#   ./prepare.sh as-requested    same, but the topics approved as requested (fault F6)
#   ./prepare.sh healthy         no faults (windpark-healthy.yaml)
#   ./prepare.sh healthy <file>  more manifests applied afterwards (for example fixes/f3-alerts.yaml)
. "$(dirname "$0")/../lib/common.sh"
need kubectl
kube_ready || die "kubectl cannot reach the cluster."
kubectl -n "$KAFKA_NAMESPACE" get kafka "$KAFKA_CLUSTER" >/dev/null 2>&1 || die "Kafka cluster is missing. Run cluster/prepare.sh first."
HERE="$(cd "$(dirname "$0")" && pwd)"
# Deployments that crash-loop on a poison pill never become ready: do not wait four minutes for each.
ROLLOUT_TIMEOUT="${ROLLOUT_TIMEOUT:-240s}"
MODE="${1:-training}"
[ $# -eq 0 ] || shift
TOPIC_VARIANT=sensible
FILES=("$HERE/windpark.yaml")
case "$MODE" in
  as-requested) TOPIC_VARIANT=as-requested ;;
  healthy) FILES=("$HERE/windpark-healthy.yaml") ;;
  training) ;;
  *) die "Unknown mode: $MODE (training, as-requested or healthy)" ;;
esac
for extra in "$@"; do
  case "$extra" in /*) FILES+=("$extra") ;; *) FILES+=("$HERE/$extra") ;; esac
done
log "Topics of the onboarding requests (${TOPIC_VARIANT})"
# Only topics that do not exist yet: never overwrite what a group has created.
# These topics exist before the naming convention. Once the governance lab has put its naming policy in place, they are
# created grandfathered (the label the lab sets by hand), otherwise the policy would reject them.
label=()
kubectl get validatingadmissionpolicy kafkatopic-naming >/dev/null 2>&1 && label=(governance.nordwind/grandfathered=true)
for f in "$HERE/topics/$TOPIC_VARIANT"/{telemetry,turbine-registry,park-registry}.yaml; do
  name="$(sed -n 's/^  name: //p' "$f")"
  if kubectl -n "$KAFKA_NAMESPACE" get kafkatopic "$name" >/dev/null 2>&1; then echo "exists: $name"
  elif [ ${#label[@]} -gt 0 ]; then kubectl label --local -f "$f" "${label[@]}" -o yaml | kubectl apply -f -
  else kubectl apply -f "$f"; fi
done

log "Wind park (${MODE})"
applied="$(for f in "${FILES[@]}"; do kubectl apply -f "$f"; done)"
echo "$applied"
# A changed ConfigMap does not restart its Deployment: restart the ones whose settings just changed.
declare -A DEPLOYMENT=([scada-config]=scada-telemetry [assets-config]=assets-stammdaten [leitwarte-config]=leitwarte
                       [abrechnung-config]=abrechnung [prognose-config]=prognose [alarme-config]=alarme)
for cm in "${!DEPLOYMENT[@]}"; do
  if grep -q "^configmap/$cm configured" <<<"$applied"; then kubectl -n windpark rollout restart "deployment/${DEPLOYMENT[$cm]}"; fi
done
# Alarme writes to one topic at a time (F3's own topic or the one that follows the naming convention): remove the other.
alerts_topic="$(kubectl -n windpark get configmap alarme-config -o jsonpath='{.data.TOPIC}')"
if [ "$alerts_topic" = windpark_alerts ]; then stale=nordwind.alarme.public.windpark-alert.event; else stale=windpark-alerts; fi
kubectl -n "$KAFKA_NAMESPACE" delete kafkatopic "$stale" --ignore-not-found
for d in scada-telemetry assets-stammdaten leitwarte prognose abrechnung alarme; do
  kubectl -n windpark rollout status "deployment/$d" --timeout="$ROLLOUT_TIMEOUT" || true
done
# A consumer stuck on the old poison pill never becomes ready; fixes/ ships with the day 2 labs.
if [ "$MODE" = healthy ] && [ -x "$HERE/fixes/skip-poison-pill.sh" ]; then
  consumers_ready() {
    local d
    for d in leitwarte prognose abrechnung; do
      [ "$(kubectl -n windpark get deployment "$d" -o jsonpath='{.status.readyReplicas}')" = "$(kubectl -n windpark get deployment "$d" -o jsonpath='{.spec.replicas}')" ] || return 1
    done
  }
  # A crash-looping pod is briefly Running between two crashes: ready has to hold for 20 seconds.
  for _ in $(seq 24); do consumers_ready && { sleep 20; consumers_ready && break; }; sleep 5; done
  consumers_ready || { log "A consumer is not ready: moving the groups behind the poison pill"; "$HERE/fixes/skip-poison-pill.sh"; }
fi
kubectl -n windpark get pods
