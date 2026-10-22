#!/usr/bin/env bash
# Counts what a producer was promised and what the topic holds.
#   ./count.sh <topic> <log written by produce.sh>
# acknowledged = send_success lines in the log; stored = records in the topic (single partition); lost = difference.
. "$(dirname "$0")/lib.sh"
topic="${1:?usage: count.sh <topic> <producer log>}"; log="${2:?usage: count.sh <topic> <producer log>}"
acked=$(grep -c '"name":"producer_send_success"' "$log" || true)
failed=$(grep -c '"name":"producer_send_error"' "$log" || true)
end=$(kt kafka-get-offsets.sh --bootstrap-server "$BOOTSTRAP" --topic "$topic" --time latest | awk -F: '{s+=$3} END {print s+0}')
start=$(kt kafka-get-offsets.sh --bootstrap-server "$BOOTSTRAP" --topic "$topic" --time earliest | awk -F: '{s+=$3} END {print s+0}')
stored=$((end - start))
printf 'acknowledged: %s\nrejected:     %s\nstored:       %s\nlost:         %s\n' "$acked" "$failed" "$stored" "$((acked - stored))"
