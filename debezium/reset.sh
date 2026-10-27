#!/usr/bin/env bash
# Removes everything the Debezium lab creates: the connector, its Kafka Connect cluster (with the build pod), the
# SCADA database (and with it the replication slot), the CDC topics and Connect's internal topics. The registry goes
# too, unless the Kafka Connect cluster of the Connect lab still pulls from it. Run it on node1. Idempotent.
. "$(dirname "$0")/../lib/common.sh"
need kubectl
kube_ready || { echo "No cluster reachable, nothing to reset."; exit 0; }
N=(-n "$KAFKA_NAMESPACE")
HERE="$(cd "$(dirname "$0")" && pwd)"
if kubectl "${N[@]}" get kafkaconnect debezium >/dev/null 2>&1; then
  kubectl "${N[@]}" delete kafkaconnector scada-cdc --ignore-not-found --timeout=120s >/dev/null || true
  kubectl "${N[@]}" delete kafkaconnect debezium --ignore-not-found --timeout=120s >/dev/null || true
  # A Connect pod that is still shutting down would create its internal topics again (auto-creation).
  kubectl "${N[@]}" wait pod -l strimzi.io/cluster=debezium --for=delete --timeout=120s >/dev/null 2>&1 || true
fi
kubectl "${N[@]}" delete kafkaconnector scada-cdc --ignore-not-found --timeout=60s >/dev/null 2>&1 || true
# The replication slot lives in the database: deleting the namespace removes both.
kubectl delete namespace scada --ignore-not-found --timeout=180s >/dev/null 2>&1 || true
kubectl "${N[@]}" delete kafkatopic scada-turbines scada-readings --ignore-not-found --timeout=120s >/dev/null 2>&1 || true
# Connect's internal topics (with the stored offsets) and anything else under the CDC prefix go via a broker.
# Left behind, the stored offsets would make a new connector skip its snapshot.
broker="$(kubectl "${N[@]}" get pod -l "strimzi.io/name=${KAFKA_CLUSTER}-kafka" -o name 2>/dev/null | head -1)"
if [ -n "$broker" ]; then
  kt() { kubectl "${N[@]}" exec "$broker" -- /opt/kafka/bin/kafka-topics.sh --bootstrap-server "${KAFKA_CLUSTER}-kafka-bootstrap:9092" "$@"; }
  pattern='^(nordwind-debezium-|nordwind\.scada\.cdc\.|nordwind\.scada\.private\.(turbines|readings)\.state$)'
  for t in $(kt --list 2>/dev/null | grep -E "$pattern" || true); do
    kt --delete --topic "$t" >/dev/null 2>&1 || true
  done
  # Deleting a topic takes a moment; the next run must not find it.
  for _ in $(seq 30); do
    kt --list 2>/dev/null | grep -qE "$pattern" || break
    sleep 2
  done
fi
if ! kubectl "${N[@]}" get kafkaconnect connect >/dev/null 2>&1; then
  kubectl delete namespace registry --ignore-not-found --timeout=120s >/dev/null 2>&1 || true
fi
# The self-checks of the lab keep a result in these marker files.
rm -f "$HOME/.debezium-silent-retry" "$HOME/.debezium-task-failed" "$HOME/.debezium-slot-grew"
# The working files go back to their frames.
cp "$HERE/connect-frame.yaml" "$HERE/connect.yaml"
cp "$HERE/connector-frame.yaml" "$HERE/connector.yaml"
echo "Debezium lab removed."
