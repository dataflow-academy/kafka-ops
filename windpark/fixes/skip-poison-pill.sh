#!/usr/bin/env bash
# Catch-up for "the poison pill is behind the consumers": stops the three consumer applications, moves their groups to
# the end of the telemetry topic, and starts them again. The lab does this by hand, with a reason for every step.
# Idempotent. Run it on node1.
. "$(dirname "$0")/../../lib/common.sh"
need kubectl
NS="$KAFKA_NAMESPACE"
TOPIC=nordwind.scada.public.turbine-telemetry.event
declare -A replicas=([leitwarte]=2 [prognose]=1 [abrechnung]=1)

for d in "${!replicas[@]}"; do kubectl -n windpark scale "deployment/$d" --replicas=0 >/dev/null; done
for d in "${!replicas[@]}"; do kubectl -n windpark wait --for=delete pod -l "app.kubernetes.io/name=$d" --timeout=120s >/dev/null 2>&1 || true; done
sleep 10   # the group coordinator forgets the members after the session timeout
for d in "${!replicas[@]}"; do
  kubectl -n "$NS" exec deploy/kafka-tools -- kafka-consumer-groups.sh --bootstrap-server "my-cluster-kafka-bootstrap:9092" \
    --group "$d" --topic "$TOPIC" --reset-offsets --to-latest --execute >/dev/null 2>&1 || echo "group $d: offsets not reset (is the application still running?)"
done
for d in "${!replicas[@]}"; do kubectl -n windpark scale "deployment/$d" --replicas="${replicas[$d]}" >/dev/null; done
