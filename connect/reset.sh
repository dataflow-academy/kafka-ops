#!/usr/bin/env bash
# Removes everything the Connect lab creates: connectors, Kafka Connect (with its build pod), the registry
# with all images, the database, the topics. The mirror entry on the nodes stays (it is harmless).
# Run it on node1. Idempotent.
. "$(dirname "$0")/../lib/common.sh"
need kubectl
kube_ready || { echo "No cluster reachable, nothing to reset."; exit 0; }
N=(-n "$KAFKA_NAMESPACE")
HERE="$(cd "$(dirname "$0")" && pwd)"
if kubectl "${N[@]}" get kafkaconnect >/dev/null 2>&1; then
  # The operator removes the KafkaConnector resources' connectors before the finalizers go.
  kubectl "${N[@]}" delete kafkaconnector,kafkaconnect --all --ignore-not-found --timeout=120s >/dev/null || true
  # A Connect pod that is still shutting down would create its internal topics again (auto-creation).
  kubectl "${N[@]}" wait pod -l strimzi.io/cluster=connect --for=delete --timeout=120s >/dev/null 2>&1 || true
fi
# Debezium's replication slot lives in the database, which is deleted below.
kubectl delete -f "$(dirname "$0")/postgres.yaml" --ignore-not-found --timeout=120s >/dev/null 2>&1 || true
kubectl "${N[@]}" delete kafkatopic maintenance-work-orders --ignore-not-found --timeout=120s >/dev/null 2>&1 || true
# Topics created by Connect and Debezium (internal topics with the stored offsets, the CDC topics) go via a broker.
# Left behind, the stored offsets would make a new connector skip the rows it has already "read".
broker="$(kubectl "${N[@]}" get pod -l "strimzi.io/name=${KAFKA_CLUSTER}-kafka" -o name 2>/dev/null | head -1)"
if [ -n "$broker" ]; then
  kt() { kubectl "${N[@]}" exec "$broker" -- /opt/kafka/bin/kafka-topics.sh --bootstrap-server "${KAFKA_CLUSTER}-kafka-bootstrap:9092" "$@"; }
  for t in $(kt --list 2>/dev/null | grep -E '^(nordwind-connect-|nordwind\.maintenance\.)' || true); do
    kt --delete --topic "$t" >/dev/null 2>&1 || true
  done
  # Deleting a topic takes a moment; the next run must not find it.
  for _ in $(seq 30); do
    kt --list 2>/dev/null | grep -qE '^(nordwind-connect-|nordwind\.maintenance\.)' || break
    sleep 2
  done
fi
kubectl delete namespace registry --ignore-not-found --timeout=120s >/dev/null 2>&1 || true
# The working files go back to their frames.
cp "$HERE/connect-frame.yaml" "$HERE/connect.yaml"
cp "$HERE/jdbc-source-frame.yaml" "$HERE/jdbc-source.yaml"
echo "Connect lab removed."
