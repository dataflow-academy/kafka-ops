#!/usr/bin/env bash
# Writes numbered records into a topic, 20 per second, and prints one JSON line per acknowledged or failed record.
#   ./produce.sh <topic> <acks: 0, 1 or all>
# Meant to run in a terminal of its own; stop it with Ctrl+C. Pipe it into tee to keep the log for count.sh.
. "$(dirname "$0")/lib.sh"
topic="${1:?usage: produce.sh <topic> <acks>}"; acks="${2:?usage: produce.sh <topic> <acks>}"
[ "$acks" = all ] && acks=-1
exec kubectl -n "$NS" exec -it deploy/kafka-tools -- kafka-verifiable-producer.sh \
  --bootstrap-server "$BOOTSTRAP" --topic "$topic" --acks "$acks" --throughput 20 --max-messages -1 --value-prefix 1
