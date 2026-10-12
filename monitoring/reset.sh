#!/usr/bin/env bash
# Removes Prometheus, kube-state-metrics, Grafana and Kafka UI with their configuration and rules. The
# metrics of the Kafka cluster stay switched on. Run it on node1. Idempotent.
. "$(dirname "$0")/../lib/common.sh"
need kubectl
kube_ready || { echo "No cluster reachable, nothing to reset."; exit 0; }
cd "$(dirname "$0")"
for f in prometheus kube-state-metrics grafana kafka-ui; do
  render "$f.yaml" | kubectl -n "$KAFKA_NAMESPACE" delete --ignore-not-found -f - 2>/dev/null || true
done
kubectl -n "$KAFKA_NAMESPACE" delete configmap dashboards-strimzi dashboards-wind-park prometheus-rules --ignore-not-found
