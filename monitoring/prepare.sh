#!/usr/bin/env bash
# Start state "monitoring done": the metrics of the Kafka cluster are on (rolling restart, once), Prometheus,
# kube-state-metrics, Grafana and Kafka UI run with the correct configuration, and the reference alerting
# rules are loaded. Needs the cluster (cluster/prepare.sh). Run it on node1. Idempotent.
. "$(dirname "$0")/../lib/common.sh"
need kubectl
HERE="$(cd "$(dirname "$0")" && pwd)"
"$HERE/metrics.sh"
"$HERE/install.sh"
log "Alerting rules"
kubectl -n "$KAFKA_NAMESPACE" create configmap prometheus-rules --from-file=rules.yml="$HERE/rules-reference.yml" --dry-run=client -o yaml | kubectl -n "$KAFKA_NAMESPACE" apply -f - >/dev/null
kubectl -n "$KAFKA_NAMESPACE" rollout restart deployment/prometheus >/dev/null
kubectl -n "$KAFKA_NAMESPACE" rollout status deployment/prometheus --timeout=120s
