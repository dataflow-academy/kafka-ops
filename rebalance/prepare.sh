#!/usr/bin/env bash
# Start state for "add a broker": the cluster is Ready with three brokers, no Cruise Control, and no topic
# nordwind.platform.private.rebalance-demo.event yet: the lab switches Cruise Control on, creates the skewed topic with
# kafka-topics.sh and fills it with kafka-producer-perf-test.sh. Run it on node1. Idempotent.
. "$(dirname "$0")/../lib/common.sh"
need kubectl
kube_ready || die "kubectl cannot reach the cluster."
N=(-n "$KAFKA_NAMESPACE")
kubectl "${N[@]}" get kafka "$KAFKA_CLUSTER" >/dev/null 2>&1 || die "Kafka cluster is missing. Run cluster/prepare.sh first."

# reset.sh does all of it: three brokers, no Cruise Control, no rebalance objects, no demo topic.
"$(dirname "$0")/reset.sh"

# The Cruise Control dashboard and the metrics configuration that spec.cruiseControl.metricsConfig refers to.
if kubectl "${N[@]}" get deployment grafana >/dev/null 2>&1; then
  kubectl apply -k "$ROOT/monitoring" >/dev/null
fi
log "Done"
kubectl "${N[@]}" get kafkanodepool,pods -l strimzi.io/cluster="$KAFKA_CLUSTER"
