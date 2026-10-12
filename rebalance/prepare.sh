#!/usr/bin/env bash
# Start state for "add a broker": the cluster is Ready with three brokers, and there is data to move
# (topic nordwind.platform.private.rebalance-demo.event, KafkaTopic resource rebalance-demo: 12 partitions,
# replication factor 3, ~600 MB). Cruise Control is NOT enabled yet and the broker pool has 3 replicas: the lab does both. Run it on node1. Idempotent.
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
  # The Kafka name follows the naming convention, so the policies of the governance lab stay in place.
  PERF_NAME=rebalance-demo PERF_TOPIC=nordwind.platform.private.rebalance-demo.event PERF_PARTITIONS=12 \
    PERF_RECORDS=600000 "$(dirname "$0")/../perf/run.sh" | tail -1
  # The perf topic expires after ten minutes; this one has to be there for the whole lab.
  kubectl "${N[@]}" patch kafkatopic rebalance-demo --type merge -p '{"spec":{"config":{"retention.ms":"604800000"}}}' >/dev/null
fi
log "Done"
kubectl "${N[@]}" get kafkanodepool,pods -l strimzi.io/cluster="$KAFKA_CLUSTER"
