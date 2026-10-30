#!/usr/bin/env bash
# Start state for the security lab: the cluster is open (plain listeners, no authorization, no users), and the
# wind park of the six teams runs without faults. A cluster that already has security switched on is taken
# back first (reset.sh, one rolling update), and Kafka Connect, Debezium and the mirror of the earlier labs go.
# Run it on node1. Idempotent.
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
# The lab switches the plaintext listeners off: whatever the earlier labs left on them goes.
kubectl "${N[@]}" get kafkaconnect connect >/dev/null 2>&1 && "$(dirname "$0")/../connect/reset.sh"
kubectl "${N[@]}" get kafkaconnect debezium >/dev/null 2>&1 && "$(dirname "$0")/../debezium/reset.sh"
kubectl "${N[@]}" get kafkamirrormaker2 mm2 >/dev/null 2>&1 && "$(dirname "$0")/../dr/reset.sh"
kubectl "${N[@]}" wait "kafka/${KAFKA_CLUSTER}" --for=condition=Ready --timeout=600s
log "Done"
