#!/usr/bin/env bash
# Copies the alerts of the old topic windpark_alerts into the new topic nordwind.alerts.public.windpark-alert.event.
# It remembers how far it has copied (~/.alerts-copied), so a second run copies only what arrived since: the team
# keeps writing into the old topic until it has been switched over. Idempotent. Run it on node1.
. "$(dirname "$0")/../lib/common.sh"
kube_ready || die "kubectl cannot reach the cluster."
NS="$KAFKA_NAMESPACE"
BS="nordwind-kafka-kafka-bootstrap:9092"
OLD=windpark_alerts
NEW=nordwind.alerts.public.windpark-alert.event
STATE="$HOME/.alerts-copied"
kt() { kubectl -n "$NS" exec -i deploy/kafka-tools -- "$@"; }
ensure_tools
# The Topic Operator needs a moment to create the topic after kubectl apply.
wait_for "the new topic $NEW" 90 kt kafka-topics.sh --bootstrap-server "$BS" --describe --topic "$NEW" || die "The new topic $NEW does not exist yet. Apply alerts-topic.yaml first."
kt kafka-topics.sh --bootstrap-server "$BS" --describe --topic "$OLD" >/dev/null 2>&1 || die "The old topic $OLD is already gone, there is nothing left to copy."
from=$(cat "$STATE" 2>/dev/null || echo 0)
end=$(kt kafka-get-offsets.sh --bootstrap-server "$BS" --topic "$OLD" --time latest | awk -F: '{s+=$3} END {print s+0}')
n=$((end - from))
if [ "$n" -le 0 ]; then echo "Nothing new to copy (offset $from of $end)."; exit 0; fi
tmp=$(mktemp)
kt kafka-console-consumer.sh --bootstrap-server "$BS" --topic "$OLD" --partition 0 --offset "$from" --max-messages "$n" \
  --formatter-property print.key=true --formatter-property key.separator='|' --timeout-ms 20000 > "$tmp" 2>/dev/null || true
copied=$(wc -l < "$tmp")
[ "$copied" -eq "$n" ] || { rm -f "$tmp"; die "Read $copied of $n alerts. Run the script again."; }
kt kafka-console-producer.sh --bootstrap-server "$BS" --topic "$NEW" \
  --reader-property parse.key=true --reader-property key.separator='|' < "$tmp"
rm -f "$tmp"
echo "$end" > "$STATE"
echo "Copied $n alerts (offsets $from to $((end - 1))) into $NEW."
