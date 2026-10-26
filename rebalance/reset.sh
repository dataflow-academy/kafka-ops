#!/usr/bin/env bash
# Back to three brokers without Cruise Control. A broker that carries replicas must not simply be
# scaled away, so broker 3 is emptied with a remove-brokers rebalance first. Run it on node1. Idempotent.
. "$(dirname "$0")/../lib/common.sh"
need kubectl
kube_ready || { echo "No cluster reachable, nothing to reset."; exit 0; }
N=(-n "$KAFKA_NAMESPACE")
kubectl "${N[@]}" get kafka "$KAFKA_CLUSTER" >/dev/null 2>&1 || { echo "No Kafka cluster, nothing to reset."; exit 0; }

# Ready counts only once the operator has processed the change: right after a patch the status still shows the
# Ready of the previous generation.
kafka_settled() {
  [ "$(kubectl "${N[@]}" get kafka "$KAFKA_CLUSTER" -o jsonpath='{.metadata.generation}')" = \
    "$(kubectl "${N[@]}" get kafka "$KAFKA_CLUSTER" -o jsonpath='{.status.observedGeneration}')" ] &&
  [ "$(kubectl "${N[@]}" get kafka "$KAFKA_CLUSTER" -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}')" = True ]
}

# Brokers that exist: status.nodeIds, not spec.replicas (the operator reverts a blocked scale-down).
# The original three have the ids 0-2; everything above is emptied.
extra=()
for id in $(kubectl "${N[@]}" get kafkanodepool broker -o jsonpath='{.status.nodeIds[*]}'); do
  if [ "$id" -ge 3 ]; then extra+=("$id"); fi
done
if [ "${#extra[@]}" -gt 0 ]; then
  extra_json="[$(IFS=,; echo "${extra[*]}")]"
  log "Emptying broker(s) ${extra[*]} (remove-brokers)"
  if ! kubectl "${N[@]}" get kafka "$KAFKA_CLUSTER" -o jsonpath='{.spec.cruiseControl}' | grep -q .; then
    kubectl "${N[@]}" patch kafka "$KAFKA_CLUSTER" --type merge -p '{"spec":{"cruiseControl":{}}}' >/dev/null
    wait_for "Kafka settled after enabling Cruise Control" 900 kafka_settled
  fi
  # A KafkaRebalance that meets a Cruise Control that is not there yet turns NotReady and is not retried.
  kubectl "${N[@]}" wait "deployment/${KAFKA_CLUSTER}-cruise-control" --for=condition=Available --timeout=300s >/dev/null
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
  brokers: ${extra_json}
EOF
  wait_for "proposal" 600 sh -c "kubectl -n $KAFKA_NAMESPACE get kafkarebalance reset-remove-broker -o jsonpath='{.status.conditions[*].type}' | grep -qw ProposalReady"
  kubectl "${N[@]}" annotate kafkarebalance reset-remove-broker strimzi.io/rebalance=approve --overwrite >/dev/null
  wait_for "rebalance" 900 sh -c "kubectl -n $KAFKA_NAMESPACE get kafkarebalance reset-remove-broker -o jsonpath='{.status.conditions[*].type}' | grep -qw Ready"
  kubectl "${N[@]}" patch kafkanodepool broker --type merge -p '{"spec":{"replicas":3}}' >/dev/null
  wait_for "Kafka settled after the scale-down" 900 kafka_settled
fi
kubectl "${N[@]}" delete kafkarebalance --all --ignore-not-found >/dev/null
# next-node-ids as the cluster is defined (cluster/kafka.yaml)
kubectl "${N[@]}" annotate kafkanodepool broker strimzi.io/next-node-ids='[0-2]' --overwrite >/dev/null
if kubectl "${N[@]}" get kafka "$KAFKA_CLUSTER" -o jsonpath='{.spec.cruiseControl}' | grep -q .; then
  log "Removing Cruise Control"
  kubectl "${N[@]}" patch kafka "$KAFKA_CLUSTER" --type json -p '[{"op":"remove","path":"/spec/cruiseControl"}]' >/dev/null
fi
wait_for "Kafka settled" 900 kafka_settled
