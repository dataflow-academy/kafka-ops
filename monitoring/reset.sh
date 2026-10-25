#!/usr/bin/env bash
# Removes Prometheus, kube-state-metrics and Grafana with their configuration and rules. Kafka UI stays (it belongs
# to the first lab), and the metrics of the Kafka cluster stay switched on. Run it on node1. Idempotent.
. "$(dirname "$0")/../lib/common.sh"
need kubectl
kube_ready || { echo "No cluster reachable, nothing to reset."; exit 0; }
cd "$(dirname "$0")" || exit 1
kubectl delete --ignore-not-found -k . 2>/dev/null || true
kubectl -n "$KAFKA_NAMESPACE" delete configmap prometheus-rules --ignore-not-found
