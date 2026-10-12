#!/usr/bin/env bash
# Start state for the failure lab: cluster, monitoring and wind park (with its faults) running, no failure
# active, the Kafka tools pod there, and the topic of team Alarme on the broker of node3 (so that the loss of that
# node shows fault F3). Idempotent. Run it on node1.
. "$(dirname "$0")/lib.sh"
need kubectl; need jq
kube_ready || die "kubectl cannot reach the cluster. Run k3s/prepare.sh first."
kubectl -n "$NS" get kafka "$KAFKA_CLUSTER" >/dev/null 2>&1 || "$ROOT/cluster/prepare.sh"
[ -x "$ROOT/monitoring/prepare.sh" ] && kubectl get deploy prometheus -n "$NS" >/dev/null 2>&1 || "$ROOT/monitoring/prepare.sh"
kubectl get ns windpark >/dev/null 2>&1 || "$ROOT/windpark/prepare.sh"
"$ROOT/tools/prepare.sh"
"$(dirname "$0")/heal.sh"

# Topic of team Alarme: one replica, put it on the broker that runs on node3.
topic=windpark_alerts
if kt kafka-topics.sh --bootstrap-server "$BOOTSTRAP" --describe --topic "$topic" >/dev/null 2>&1; then
  target=$(kubectl -n "$NS" get pods -l strimzi.io/pool-name=broker -o json \
    | jq -r '.items[] | select(.spec.nodeName | endswith("node3")) | .metadata.name | sub(".*-"; "")' | head -1)
  current=$(kt kafka-topics.sh --bootstrap-server "$BOOTSTRAP" --describe --topic "$topic" | sed -n 's/.*Replicas: \([0-9]*\).*/\1/p' | head -1)
  if [ -n "$target" ] && [ "$current" != "$target" ]; then
    log "Moving $topic to broker $target (node3)"
    echo "{\"version\":1,\"partitions\":[{\"topic\":\"$topic\",\"partition\":0,\"replicas\":[$target]}]}" \
      | kubectl -n "$NS" exec -i deploy/kafka-tools -- sh -c 'cat > /tmp/move.json && kafka-reassign-partitions.sh --bootstrap-server '"$BOOTSTRAP"' --reassignment-json-file /tmp/move.json --execute' >/dev/null
    sleep 10
  fi
fi
log "Failure lab ready"
