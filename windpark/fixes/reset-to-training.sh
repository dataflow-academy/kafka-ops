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
# The end of the lab switches topic auto-creation off; fault F1 needs it on. Only then the cluster rolls (minutes).
if [ -n "$(kubectl -n "$NS" get kafka "$KAFKA_CLUSTER" -o 'jsonpath={.spec.kafka.config.auto\.create\.topics\.enable}')" ]; then
  log "Switching topic auto-creation back on (rolling restart)"
  kubectl -n "$NS" patch kafka "$KAFKA_CLUSTER" --type merge \
    -p '{"spec":{"kafka":{"config":{"auto.create.topics.enable":null,"num.partitions":null}}}}'
  # The working file of the lab has to describe the running cluster again.
  sed -i '/^ *auto\.create\.topics\.enable:/d; /^ *num\.partitions:/d' "$ROOT/cluster/nordwind-kafka.yaml"
  kafka_settled() {
    [ "$(kubectl -n "$NS" get kafka "$KAFKA_CLUSTER" -o jsonpath='{.metadata.generation}')" = \
      "$(kubectl -n "$NS" get kafka "$KAFKA_CLUSTER" -o jsonpath='{.status.observedGeneration}')" ] &&
    [ "$(kubectl -n "$NS" get kafka "$KAFKA_CLUSTER" -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}')" = True ]
  }
  wait_for "the rolling restart of $KAFKA_CLUSTER" 900 kafka_settled
fi
# Left over from the deep dive that moves team Alerts (migrate-alerts.sh).
rm -f "$HOME/.alerts-copied"
"$ROOT/windpark/prepare.sh"
# The maintenance tool writes its pill only every 20 minutes; do not wait for it.
kubectl -n windpark create job --from=cronjob/maintenance-report "maintenance-start-$(date +%s)" >/dev/null
log "Wind park with faults ready"
