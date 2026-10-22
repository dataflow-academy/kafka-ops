#!/usr/bin/env bash
# Starts the three experiment producers (telemetry, billing, alerts) in one terminal. Every producer writes numbered
# records, 20 per second, and logs each acknowledgment or error to /tmp/<name>.log inside the tools pod. Every
# 5 seconds this script prints how many were acknowledged and how many failed. Stop everything with Ctrl+C.
#
#   ACKS_TELEMETRY=<0|1|all> ACKS_BILLING=<0|1|all> ACKS_ALERTS=<0|1|all> ./start-producers.sh
#
# The producers run as one process group inside the pod (xargs), because a process in the pod cannot be killed
# from outside: Ctrl+C reaches the group through the terminal, nothing is left behind.
. "$(dirname "$0")/lib.sh"
declare -A acks=([telemetry]="${ACKS_TELEMETRY:-}" [billing]="${ACKS_BILLING:-}" [alerts]="${ACKS_ALERTS:-}")
for k in telemetry billing alerts; do
  case "${acks[$k]}" in 0|1|all) ;; *) die "ACKS_${k^^} must be 0, 1 or all (got '${acks[$k]}').";; esac
  [ "${acks[$k]}" = all ] && acks[$k]=-1
done
ensure_tools
# This program runs in the tools pod; its shell variables must stay literal here.
# shellcheck disable=SC2016
job='k={}
case $k in
  telemetry) a='"${acks[telemetry]}"';; billing) a='"${acks[billing]}"';; alerts) a='"${acks[alerts]}"';;
esac
if [ "$k" = status ]; then
  while sleep 5; do
    line=$(date +%T)
    for n in telemetry billing alerts; do
      line="$line   $n: $(grep -c producer_send_success /tmp/$n.log) ok, $(grep -c producer_send_error /tmp/$n.log) errors"
    done
    echo "$line"
  done
else
  exec kafka-verifiable-producer.sh --bootstrap-server '"$BOOTSTRAP"' --topic chaos-$k \
    --acks $a --throughput 20 --max-messages -1 --value-prefix 1 > /tmp/$k.log 2>&1
fi'
for k in telemetry billing alerts; do : ; done
echo "Producers running: telemetry acks=${ACKS_TELEMETRY}, billing acks=${ACKS_BILLING}, alerts acks=${ACKS_ALERTS}. Ctrl+C stops them."
exec kubectl -n "$NS" exec -it deploy/kafka-tools -- sh -c \
  "for k in telemetry billing alerts; do : > /tmp/\$k.log; done; printf 'telemetry\nbilling\nalerts\nstatus\n' | xargs -P4 -I{} sh -c '$(printf '%s' "$job" | sed "s/'/'\\\\''/g")'"
