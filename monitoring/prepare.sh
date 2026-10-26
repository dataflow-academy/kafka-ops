#!/usr/bin/env bash
# Start state "monitoring installed": Prometheus, Grafana (with the Strimzi
# dashboards of the pinned release) and Kafka UI, reachable on the NodePorts of
# every node:  Grafana 30300 (admin/admin), Prometheus 30900, Kafka UI 30800.
# Needs the cluster (cluster/prepare.sh). Run it on node1. Idempotent.
. "$(dirname "$0")/../lib/common.sh"
need kubectl
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

log "Prometheus, Grafana, Kafka UI"
for f in prometheus grafana kafka-ui; do kubectl "${N[@]}" apply -f "$f.yaml"; done
for d in prometheus grafana kafka-ui; do kubectl "${N[@]}" rollout status "deployment/$d" --timeout=240s; done
log "Done: Grafana :30300, Prometheus :30900, Kafka UI :30800 on any node"
