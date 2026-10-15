#!/usr/bin/env bash
# Puts the topic of team Alarme (windpark_alerts, one replica, fault F3) on the broker that runs on node3, so that
# every group finds it on the same node when that node fails. Idempotent. Run it on node1.
. "$(dirname "$0")/lib.sh"
need kubectl; need jq
kube_ready || die "kubectl cannot reach the cluster."
ensure_tools
topic=windpark_alerts
kt kafka-topics.sh --bootstrap-server "$BOOTSTRAP" --describe --topic "$topic" >/dev/null 2>&1 \
  || die "Topic $topic does not exist. Run windpark/prepare.sh first."
target=$(kubectl -n "$NS" get pods -l strimzi.io/pool-name=broker -o json \
  | jq -r '.items[] | select(.spec.nodeName | endswith("node3")) | .metadata.name | sub(".*-"; "")' | head -1)
[ -n "$target" ] || die "No broker runs on node3."
current=$(kt kafka-topics.sh --bootstrap-server "$BOOTSTRAP" --describe --topic "$topic" | sed -n 's/.*Replicas: \([0-9]*\).*/\1/p' | head -1)
if [ "$current" != "$target" ]; then
  log "Moving $topic to broker $target (node3)"
  echo "{\"version\":1,\"partitions\":[{\"topic\":\"$topic\",\"partition\":0,\"replicas\":[$target]}]}" \
    | kubectl -n "$NS" exec -i deploy/kafka-tools -- sh -c 'cat > /tmp/move.json && kafka-reassign-partitions.sh --bootstrap-server '"$BOOTSTRAP"' --reassignment-json-file /tmp/move.json --execute' >/dev/null
  sleep 10
fi
echo "Topic $topic is on broker $target (node3)."
