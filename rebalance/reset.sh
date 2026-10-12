#!/usr/bin/env bash
# Back to three brokers without Cruise Control. A broker that carries replicas must not simply be
# scaled away, so broker 3 is emptied with a remove-brokers rebalance first. Run it on node1. Idempotent.
. "$(dirname "$0")/../lib/common.sh"
need kubectl
kube_ready || { echo "No cluster reachable, nothing to reset."; exit 0; }
N=(-n "$KAFKA_NAMESPACE")
kubectl "${N[@]}" get kafka "$KAFKA_CLUSTER" >/dev/null 2>&1 || { echo "No Kafka cluster, nothing to reset."; exit 0; }

# Brokers that exist: status.nodeIds, not spec.replicas (the operator reverts a blocked scale-down).
ids="$(kubectl "${N[@]}" get kafkanodepool broker -o jsonpath='{.status.nodeIds}')"
if echo "$ids" | grep -q ',3'; then
  log "Emptying broker 3 (remove-brokers)"
  if ! kubectl "${N[@]}" get kafka "$KAFKA_CLUSTER" -o jsonpath='{.spec.cruiseControl}' | grep -q .; then
    kubectl "${N[@]}" patch kafka "$KAFKA_CLUSTER" --type merge -p '{"spec":{"cruiseControl":{}}}' >/dev/null
    kubectl "${N[@]}" wait "kafka/${KAFKA_CLUSTER}" --for=condition=Ready --timeout=900s
  fi
  kubectl "${N[@]}" delete kafkarebalance --all --ignore-not-found >/dev/null
  # The lab's own KafkaRebalance objects are gone; this one is ours.
  cat <<EOF | kubectl "${N[@]}" apply -f - >/dev/null
apiVersion: kafka.strimzi.io/v1
kind: KafkaRebalance
metadata:
  name: reset-remove-broker
  labels: { strimzi.io/cluster: ${KAFKA_CLUSTER} }
spec:
  mode: remove-brokers
  brokers: [3]
EOF
  wait_for "proposal" 600 sh -c "kubectl -n $KAFKA_NAMESPACE get kafkarebalance reset-remove-broker -o jsonpath='{.status.conditions[*].type}' | grep -qw ProposalReady"
  kubectl "${N[@]}" annotate kafkarebalance reset-remove-broker strimzi.io/rebalance=approve --overwrite >/dev/null
  wait_for "rebalance" 900 sh -c "kubectl -n $KAFKA_NAMESPACE get kafkarebalance reset-remove-broker -o jsonpath='{.status.conditions[*].type}' | grep -qw Ready"
  kubectl "${N[@]}" patch kafkanodepool broker --type merge -p '{"spec":{"replicas":3}}' >/dev/null
fi
kubectl "${N[@]}" delete kafkarebalance --all --ignore-not-found >/dev/null
# next-node-ids as the cluster is defined (cluster/kafka.yaml)
kubectl "${N[@]}" annotate kafkanodepool broker strimzi.io/next-node-ids='[0-2]' --overwrite >/dev/null
if kubectl "${N[@]}" get kafka "$KAFKA_CLUSTER" -o jsonpath='{.spec.cruiseControl}' | grep -q .; then
  log "Removing Cruise Control"
  kubectl "${N[@]}" patch kafka "$KAFKA_CLUSTER" --type json -p '[{"op":"remove","path":"/spec/cruiseControl"}]' >/dev/null
fi
kubectl "${N[@]}" wait "kafka/${KAFKA_CLUSTER}" --for=condition=Ready --timeout=900s
