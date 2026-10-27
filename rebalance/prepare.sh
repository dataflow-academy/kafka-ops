#!/usr/bin/env bash
# Start state for "add a broker": the cluster is Ready with three brokers, and there is data to move
# (load.yaml: topic nordwind.platform.private.rebalance-demo.event, KafkaTopic resource rebalance-demo: 12
# partitions, replication factor 3, ~600 MB). Cruise Control is NOT enabled yet and the broker pool has 3 replicas: the lab does both. Run it on node1. Idempotent.
. "$(dirname "$0")/../lib/common.sh"
need kubectl
kube_ready || die "kubectl cannot reach the cluster."
N=(-n "$KAFKA_NAMESPACE")
kubectl "${N[@]}" get kafka "$KAFKA_CLUSTER" >/dev/null 2>&1 || die "Kafka cluster is missing. Run cluster/prepare.sh first."

replicas="$(kubectl "${N[@]}" get kafkanodepool broker -o jsonpath='{.spec.replicas}')"
if [ "$replicas" != 3 ] || kubectl "${N[@]}" get kafka "$KAFKA_CLUSTER" -o jsonpath='{.spec.cruiseControl}' | grep -q .; then
  log "Cluster is not in the start state (brokers: $replicas), running reset.sh first"
  "$(dirname "$0")/reset.sh"
fi

kubectl "${N[@]}" wait "kafka/${KAFKA_CLUSTER}" --for=condition=Ready --timeout=600s
if ! kubectl "${N[@]}" get kafkatopic rebalance-demo >/dev/null 2>&1; then
  log "Load: topic nordwind.platform.private.rebalance-demo.event"
  # A finished Job of an earlier run would answer "complete" without writing anything.
  kubectl "${N[@]}" delete job rebalance-demo --ignore-not-found >/dev/null
  kubectl apply -f "$(dirname "$0")/load.yaml"
  kubectl "${N[@]}" wait job/rebalance-demo --for=condition=Complete --timeout=900s \
    || { kubectl "${N[@]}" logs job/rebalance-demo | tail -20; die "Load run failed."; }
fi
log "Done"
kubectl "${N[@]}" get kafkanodepool,pods -l strimzi.io/cluster="$KAFKA_CLUSTER"
