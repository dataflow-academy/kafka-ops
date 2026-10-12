#!/usr/bin/env bash
# Start state for the security lab: the cluster is open (plain listeners, no authorization, no users), and the
# wind park of the six teams runs without faults. A cluster that already has security switched on is taken
# back first (reset.sh, one rolling update). Run it on node1. Idempotent.
. "$(dirname "$0")/../lib/common.sh"
need kubectl
kube_ready || die "kubectl cannot reach the cluster."
N=(-n "$KAFKA_NAMESPACE")
kubectl "${N[@]}" get kafka "$KAFKA_CLUSTER" >/dev/null 2>&1 || die "Kafka cluster is missing. Run cluster/prepare.sh first."

if [ -n "$(kubectl "${N[@]}" get kafka "$KAFKA_CLUSTER" -o jsonpath='{.spec.kafka.authorization.type}')" ] \
   || [ -n "$(kubectl "${N[@]}" get kafkauser -o name)" ]; then
  "$(dirname "$0")/reset.sh"
else
  "$(dirname "$0")/../windpark/prepare.sh" healthy
fi
kubectl "${N[@]}" wait "kafka/${KAFKA_CLUSTER}" --for=condition=Ready --timeout=600s
log "Done"
