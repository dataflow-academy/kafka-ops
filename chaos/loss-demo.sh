#!/usr/bin/env bash
# Counts how many acknowledged records a leader crash costs. Run it on node1.
#
#   ./loss-demo.sh <topic> <acks: 0, 1 or all>
#
# What it does, in this order:
#   1. cuts the followers of the partition off from replication (the replication port is dropped on their nodes),
#      so they stay in the in-sync replica set for another 30 seconds while they fall behind
#   2. writes 100 numbered records per second for 8 seconds with the given acks
#   3. kills the leader without a goodbye (SIGKILL), one of the stale followers takes over
#   4. restores the network, waits until the old leader has rejoined, and counts
# The topic must have one partition and three replicas (topics.yaml).
. "$(dirname "$0")/lib.sh"
topic="${1:?usage: loss-demo.sh <topic> <acks>}"; acks="${2:?usage: loss-demo.sh <topic> <acks>}"
ensure_tools
describe() { kt kafka-topics.sh --bootstrap-server "$BOOTSTRAP" --describe --topic "$topic" | sed -n '2p'; }
leader=$(describe | sed -n 's/.*Leader: \([0-9]*\).*/\1/p')
followers=$(describe | sed -n 's/.*Replicas: \([0-9,]*\).*/\1/p' | tr ',' '\n' | grep -vx "$leader")
log "Partition of $topic: leader broker $leader, followers $followers"

nodes=()
for b in $followers; do nodes+=("$(node_of_pod "$(broker_pod "$b")")"); done
restore() { for n in "${nodes[@]}"; do on_node "$n" "for d in dport sport; do while iptables -t raw -D PREROUTING -p tcp --\$d 9091 -j DROP 2>/dev/null; do :; done; done" >/dev/null 2>&1; done; }
trap restore EXIT

before=$(kt kafka-get-offsets.sh --bootstrap-server "$BOOTSTRAP" --topic "$topic" --time latest | awk -F: '{s+=$3} END {print s+0}')
log "Cutting off the followers on ${nodes[*]}"
# The helper pod that sets the rules can fail on the first try (image pull, attach); without the cut the demo would
# lose nothing and teach the wrong thing. So every node is checked, and set again until the rules are there.
for n in "${nodes[@]}"; do
  for attempt in 1 2 3 4 5; do
    on_node "$n" 'iptables -t raw -C PREROUTING -p tcp --dport 9091 -j DROP 2>/dev/null || { iptables -t raw -I PREROUTING 1 -p tcp --dport 9091 -j DROP; iptables -t raw -I PREROUTING 1 -p tcp --sport 9091 -j DROP; }; iptables -t raw -C PREROUTING -p tcp --sport 9091 -j DROP && echo CUT-OK' | grep -q CUT-OK && break
    [ "$attempt" -lt 5 ] || die "Could not cut off the replication on $n."
    sleep 2
  done
done

a=$acks; [ "$a" = all ] && a=-1
out=$(mktemp)
log "Writing for 8 seconds with acks=$acks"
kubectl -n "$NS" exec -i deploy/kafka-tools -- timeout 14 kafka-verifiable-producer.sh --bootstrap-server "$BOOTSTRAP" \
  --topic "$topic" --acks "$a" --throughput 100 --max-messages 800 > "$out" 2>&1 &
producer=$!
sleep 9
log "Killing broker $leader"
# Without the operator the pod stays away, so a follower really has to take over.
operator_scale 0
kubectl -n "$NS" delete pod "$(broker_pod "$leader")" --grace-period=0 --force >/dev/null 2>&1
# The controller needs the broker session timeout (9 s) to notice; a follower takes over after that.
sleep 16
restore
operator_up
kill "$producer" 2>/dev/null || true
log "Waiting for broker $leader to rejoin"
wait_for "broker $leader ready" 300 kubectl -n "$NS" wait "pod/$(broker_pod "$leader")" --for=condition=Ready --timeout=5s
wait_for "all replicas in sync" 300 bash -c "kubectl -n $NS exec deploy/kafka-tools -- kafka-topics.sh --bootstrap-server $BOOTSTRAP --describe --topic $topic | grep -q 'Isr: [0-9],[0-9],[0-9]'"
sleep 5
after=$(kt kafka-get-offsets.sh --bootstrap-server "$BOOTSTRAP" --topic "$topic" --time latest | awk -F: '{s+=$3} END {print s+0}')
acked=$(grep -c '"name":"producer_send_success"' "$out" || true)
failed=$(grep -c '"name":"producer_send_error"' "$out" || true)
stored=$((after - before))
echo
printf 'acks=%s\nacknowledged by the broker: %s\nrejected with an error:      %s\nstored in the topic:         %s\n' "$acks" "$acked" "$failed" "$stored"
if [ "$acked" -gt "$stored" ]; then printf 'acknowledged but gone:       %s\n' "$((acked - stored))"; else echo "acknowledged but gone:       0"; fi
echo "$(date +%T) $topic acks=$acks acknowledged=$acked rejected=$failed stored=$stored gone=$((acked > stored ? acked - stored : 0))" >> "$HOME/loss-demo.log"
rm -f "$out"
