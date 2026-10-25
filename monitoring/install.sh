#!/usr/bin/env bash
# Installs Prometheus, kube-state-metrics, Grafana (with the dashboards) and Kafka UI in the namespace `kafka`.
# Reachable on the NodePorts of every node: Grafana 30300 (admin/admin), Prometheus 30900, Kafka UI 30800.
# Does not touch the Kafka cluster (metrics.sh does) and loads no alerting rules. Idempotent.
#
#   ./install.sh          the correct Prometheus configuration (without the scrape fault of the lab)
#
# The monitoring lab applies the same files by hand with `kubectl apply -k`; there the fault is still in
# prometheus.yaml (the drop rule after the comment about the Kafka Exporter's own job) and the participants repair it.
. "$(dirname "$0")/../lib/common.sh"
need kubectl
kube_ready || die "kubectl cannot reach the cluster."
kubectl get namespace "$KAFKA_NAMESPACE" >/dev/null 2>&1 || die "Namespace ${KAFKA_NAMESPACE} is missing. Run cluster/prepare.sh first."
HERE="$(cd "$(dirname "$0")" && pwd)"

log "Prometheus, kube-state-metrics, Grafana with the dashboards"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
cp -r "$HERE/." "$tmp/"
sed -i '/The Kafka Exporter has its own job/,+3d' "$tmp/prometheus.yaml"
kubectl apply -k "$tmp" >/dev/null
kubectl apply -f "$HERE/../kafka-ui/kafka-ui.yaml" >/dev/null
# A changed Prometheus configuration only takes effect in a new pod.
kubectl -n "$KAFKA_NAMESPACE" rollout restart deployment/prometheus >/dev/null
for d in prometheus kube-state-metrics grafana kafka-ui; do kubectl -n "$KAFKA_NAMESPACE" rollout status "deployment/$d" --timeout=240s; done
log "Done: Grafana :30300, Prometheus :30900, Kafka UI :30800 on any node"
