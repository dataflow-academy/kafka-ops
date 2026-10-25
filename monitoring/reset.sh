#!/usr/bin/env bash
# Removes Prometheus, kube-state-metrics and Grafana with their configuration and rules. Kafka UI stays (it belongs
# to the first lab), and the metrics of the Kafka cluster stay switched on. Run it on node1. Idempotent.
. "$(dirname "$0")/../lib/common.sh"
need kubectl
kube_ready || { echo "No cluster reachable, nothing to reset."; exit 0; }
cd "$(dirname "$0")" || exit 1
for f in prometheus.yaml kube-state-metrics.yaml grafana.yaml; do
  kubectl -n "$KAFKA_NAMESPACE" delete --ignore-not-found -f "$f" 2>/dev/null || true
done
kubectl -n "$KAFKA_NAMESPACE" delete configmap dashboards-strimzi dashboards-wind-park prometheus-rules --ignore-not-found
