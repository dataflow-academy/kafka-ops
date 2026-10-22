#!/usr/bin/env bash
# Installs Prometheus, kube-state-metrics, Grafana (with the dashboards) and Kafka UI in the namespace `kafka`.
# Reachable on the NodePorts of every node: Grafana 30300 (admin/admin), Prometheus 30900, Kafka UI 30800.
# Does not touch the Kafka cluster (metrics.sh does) and loads no alerting rules. Idempotent.
#
#   ./install.sh          the correct Prometheus configuration
#   ./install.sh --lab    the configuration the monitoring lab starts with: one scrape target is missing
. "$(dirname "$0")/../lib/common.sh"
need kubectl; need envsubst
kube_ready || die "kubectl cannot reach the cluster."
kubectl get namespace "$KAFKA_NAMESPACE" >/dev/null 2>&1 || die "Namespace ${KAFKA_NAMESPACE} is missing. Run cluster/prepare.sh first."
cd "$(dirname "$0")" || exit 1
N=(-n "$KAFKA_NAMESPACE")

log "Grafana dashboards"
# The Strimzi dashboards are import files with a ${DS_PROMETHEUS} input; the
# provisioned data source has the fixed uid "prometheus" instead.
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
for f in strimzi-kafka strimzi-kraft strimzi-kafka-exporter strimzi-operators; do
  # Grafana exports this literal placeholder; the local shell must not expand it.
  # shellcheck disable=SC2016
  sed 's/\${DS_PROMETHEUS}/prometheus/g' "dashboards/$f.json" > "$tmp/$f.json"
done
kubectl "${N[@]}" create configmap dashboards-strimzi --from-file="$tmp" --dry-run=client -o yaml | kubectl "${N[@]}" apply --server-side --force-conflicts -f - >/dev/null
kubectl "${N[@]}" create configmap dashboards-wind-park --from-file=dashboards/wind-park.json --dry-run=client -o yaml | kubectl "${N[@]}" apply -f - >/dev/null

log "Prometheus, kube-state-metrics, Grafana, Kafka UI"
EXPORTER_DROP='          # The Kafka Exporter has its own job further down.\n          - source_labels: [__meta_kubernetes_pod_label_strimzi_io_name]\n            regex: .*-kafka-exporter\n            action: drop'
for f in prometheus kube-state-metrics grafana kafka-ui; do
  if [ "$f" = prometheus ]; then
    if [ "${1:-}" = "--lab" ]; then render "$f.yaml" | sed "s|^ *#LAB:EXPORTER-DROP|$EXPORTER_DROP|" | kubectl "${N[@]}" apply -f - >/dev/null
    else render "$f.yaml" | sed '/#LAB:EXPORTER-DROP/d' | kubectl "${N[@]}" apply -f - >/dev/null; fi
  else apply_tpl "$f.yaml" "${N[@]}" >/dev/null; fi
done
# A changed Prometheus configuration only takes effect in a new pod.
kubectl "${N[@]}" rollout restart deployment/prometheus >/dev/null
for d in prometheus kube-state-metrics grafana kafka-ui; do kubectl "${N[@]}" rollout status "deployment/$d" --timeout=240s; done
log "Done: Grafana :30300, Prometheus :30900, Kafka UI :30800 on any node"
