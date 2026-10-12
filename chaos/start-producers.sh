#!/usr/bin/env bash
# Starts the three experiment producers (telemetry, billing, alerts) in one terminal. Every producer writes numbered
# records, 20 per second, and logs each acknowledgment or error to ~/telemetry.log, ~/billing.log and ~/alerts.log
# (count.sh reads these logs). Every 5 seconds this script prints how many were acknowledged and how many failed.
# Stop everything with Ctrl+C; running it again stops leftovers first.
#
#   ACKS_TELEMETRY=<0|1|all> ACKS_BILLING=<0|1|all> ACKS_ALERTS=<0|1|all> ./start-producers.sh
. "$(dirname "$0")/lib.sh"
declare -A acks=([telemetry]="${ACKS_TELEMETRY:-}" [billing]="${ACKS_BILLING:-}" [alerts]="${ACKS_ALERTS:-}")
for k in telemetry billing alerts; do
  case "${acks[$k]}" in 0|1|all) ;; *) die "ACKS_${k^^} must be 0, 1 or all (got '${acks[$k]}').";; esac
done
ensure_tools
stop() {
  kt sh -c 'for f in /tmp/chaos-producer-*.pid; do [ -f "$f" ] && kill "$(cat "$f")" 2>/dev/null; rm -f "$f"; done; true' >/dev/null 2>&1 || true
}
stop
pids=()
trap 'trap - INT TERM EXIT; kill "${pids[@]}" 2>/dev/null; stop; echo; echo "Producers stopped."; exit 0' INT TERM EXIT
for k in telemetry billing alerts; do
  a="${acks[$k]}"; [ "$a" = all ] && a=-1
  : > "$HOME/$k.log"
  kubectl -n "$NS" exec -i deploy/kafka-tools -- sh -c "echo \$\$ > /tmp/chaos-producer-$k.pid; exec kafka-verifiable-producer.sh \
    --bootstrap-server $BOOTSTRAP --topic nordwind.chaos.private.$k.event --acks $a --throughput 20 --max-messages -1 --value-prefix 1" \
    > "$HOME/$k.log" 2>&1 &
  pids+=($!)
done
echo "Producers running: telemetry acks=${acks[telemetry]}, billing acks=${acks[billing]}, alerts acks=${acks[alerts]}. Ctrl+C stops them."
while true; do
  sleep 5
  line="$(date +%T)"
  for k in telemetry billing alerts; do
    ok=$(grep -c '"name":"producer_send_success"' "$HOME/$k.log" || true)
    err=$(grep -c '"name":"producer_send_error"' "$HOME/$k.log" || true)
    line+="   $k: $ok ok, $err errors"
  done
  echo "$line"
done
