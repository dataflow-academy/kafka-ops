#!/usr/bin/env bash
# Start state "wind park running": the applications of the six teams in the namespace `windpark`,
# with the faults F1-F5 built in (see README). Needs the cluster (cluster/prepare.sh). Run it on node1.
# Idempotent.
#
#   ./prepare.sh                 faulty wind park (windpark-faulty.yaml); the topics of the onboarding requests are
#                                created as a careful platform team would (only if they do not exist yet)
#   ./prepare.sh as-requested    same, but the topics approved as requested (fault F6)
#   ./prepare.sh healthy         no faults (windpark-healthy.yaml)
. "$(dirname "$0")/../lib/common.sh"
need kubectl
kube_ready || die "kubectl cannot reach the cluster."
kubectl -n "$KAFKA_NAMESPACE" get kafka "$KAFKA_CLUSTER" >/dev/null 2>&1 || die "Kafka cluster is missing. Run cluster/prepare.sh first."
HERE="$(cd "$(dirname "$0")" && pwd)"
# How long the script waits for each Deployment to become ready.
ROLLOUT_TIMEOUT="${ROLLOUT_TIMEOUT:-240s}"
# The consumers of the telemetry topic. With the faults built in they crash-loop on the poison pill on purpose
# (fault F2) and never become ready: the faulty start states do not wait for them.
TELEMETRY_CONSUMERS=(control-room forecast billing)
MODE="${1:-training}"
TOPIC_VARIANT=sensible
FILES=("$HERE/windpark-faulty.yaml")
case "$MODE" in
  as-requested) TOPIC_VARIANT=as-requested ;;
  healthy) FILES=("$HERE/windpark-healthy.yaml") ;;
  training) ;;
  *) die "Unknown mode: $MODE (training, as-requested or healthy)" ;;
esac
log "Topics of the onboarding requests (${TOPIC_VARIANT})"
# Only topics that do not exist yet: never overwrite what a group has created.
for f in "$HERE/topics/$TOPIC_VARIANT"/{telemetry,turbine-registry,park-registry,maintenance-reports}.yaml; do
  name="$(sed -n 's/^  name: //p' "$f")"
  if kubectl -n "$KAFKA_NAMESPACE" get kafkatopic "$name" >/dev/null 2>&1; then echo "exists: $name"
  else kubectl apply -f "$f"; fi
done

log "Wind park (${MODE})"
# windpark.yaml is the working file of the labs (they edit it and apply it): it takes over the state of this start state.
cp "${FILES[0]}" "$HERE/windpark.yaml"
applied="$(for f in "${FILES[@]}"; do kubectl apply -f "$f"; done)"
echo "$applied"
# A changed ConfigMap does not restart its Deployment: restart the ones whose settings just changed.
declare -A DEPLOYMENT=([scada-config]=scada-telemetry [assets-config]=assets-masterdata [control-room-config]=control-room
                       [billing-config]=billing [forecast-config]=forecast [alerts-config]=alerts)
for cm in "${!DEPLOYMENT[@]}"; do
  if grep -q "^configmap/$cm configured" <<<"$applied"; then kubectl -n windpark rollout restart "deployment/${DEPLOYMENT[$cm]}"; fi
done
WAIT_FOR=(scada-telemetry assets-masterdata alerts)
[ "$MODE" = healthy ] && WAIT_FOR+=("${TELEMETRY_CONSUMERS[@]}")
for d in "${WAIT_FOR[@]}"; do
  kubectl -n windpark rollout status "deployment/$d" --timeout="$ROLLOUT_TIMEOUT" || true
done
# Alerts writes to one topic at a time (F3's own topic or the one with three replicas it moves to): remove the other,
# in Kafka too. Only once the old pod has stopped: with topic auto-creation on it would create the topic again.
alerts_topic="$(kubectl -n windpark get configmap alerts-config -o jsonpath='{.data.TOPIC}')"
if [ "$alerts_topic" = windpark_alerts ]; then stale=nordwind.alerts.public.windpark-alert.event; stale_topic=$stale
else stale=windpark-alerts; stale_topic=windpark_alerts; fi
for _ in $(seq 40); do
  [ "$(kubectl -n windpark get pods -l app.kubernetes.io/name=alerts --no-headers | wc -l)" -le 1 ] && break
  sleep 3
done
kubectl -n "$KAFKA_NAMESPACE" delete kafkatopic "$stale" --ignore-not-found
ensure_tools
kubectl -n "$KAFKA_NAMESPACE" exec deploy/kafka-tools -- kafka-topics.sh --bootstrap-server "$KAFKA_CLUSTER-kafka-bootstrap:9092" \
  --delete --if-exists --topic "$stale_topic"
# A consumer stuck on the old poison pill never becomes ready; fixes/ ships with the day 2 labs.
if [ "$MODE" = healthy ] && [ -x "$HERE/fixes/skip-poison-pill.sh" ]; then
  consumers_ready() {
    local d
    for d in "${TELEMETRY_CONSUMERS[@]}"; do
      [ "$(kubectl -n windpark get deployment "$d" -o jsonpath='{.status.readyReplicas}')" = "$(kubectl -n windpark get deployment "$d" -o jsonpath='{.spec.replicas}')" ] || return 1
    done
  }
  # A crash-looping pod is briefly Running between two crashes: ready has to hold for 20 seconds.
  for _ in $(seq 24); do consumers_ready && { sleep 20; consumers_ready && break; }; sleep 5; done
  consumers_ready || { log "A consumer is not ready: moving the groups behind the poison pill"; "$HERE/fixes/skip-poison-pill.sh"; }
fi
kubectl -n windpark get pods
