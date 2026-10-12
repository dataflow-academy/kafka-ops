#!/usr/bin/env bash
# Start state "monitoring installed": Prometheus, Grafana (with the Strimzi
# dashboards of the pinned release) and Kafka UI, reachable on the NodePorts of
# every node:  Grafana 30300 (admin/admin), Prometheus 30900, Kafka UI 30800.
# Also switches on the metrics of the Kafka cluster (a rolling restart, once). Needs the cluster
# (cluster/prepare.sh). Run it on node1. Idempotent.
. "$(dirname "$0")/../lib/common.sh"
need kubectl; need envsubst
kube_ready || die "kubectl cannot reach the cluster."
kubectl get namespace "$KAFKA_NAMESPACE" >/dev/null 2>&1 || die "Namespace ${KAFKA_NAMESPACE} is missing. Run cluster/prepare.sh first."
cd "$(dirname "$0")"
N=(-n "$KAFKA_NAMESPACE")

log "Metrics of the Kafka cluster (JMX Prometheus Exporter, Kafka Exporter)"
# Switching them on rolls every broker and controller. Nothing happens if they are on already.
kubectl "${N[@]}" apply -f kafka-metrics-config.yaml >/dev/null
if [ -z "$(kubectl "${N[@]}" get kafka "$KAFKA_CLUSTER" -o jsonpath='{.spec.kafka.metricsConfig.type}')" ]; then
  kubectl "${N[@]}" patch kafka "$KAFKA_CLUSTER" --type merge -p '{"spec":{
    "kafka":{"metricsConfig":{"type":"jmxPrometheusExporter","valueFrom":{"configMapKeyRef":{"name":"kafka-metrics","key":"kafka-metrics-config.yml"}}}},
    "kafkaExporter":{"topicRegex":".*","groupRegex":".*"}}}'
  sleep 10
  kubectl "${N[@]}" wait "kafka/${KAFKA_CLUSTER}" --for=condition=Ready --timeout=900s
fi

log "Grafana dashboards"
# The Strimzi dashboards are import files with a ${DS_PROMETHEUS} input; the
# provisioned data source has the fixed uid "prometheus" instead.
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
for f in strimzi-kafka strimzi-kraft strimzi-kafka-exporter strimzi-operators; do
  sed 's/\${DS_PROMETHEUS}/prometheus/g' "dashboards/$f.json" > "$tmp/$f.json"
done
kubectl "${N[@]}" create configmap dashboards-strimzi --from-file="$tmp" --dry-run=client -o yaml | kubectl "${N[@]}" apply --server-side --force-conflicts -f - >/dev/null
kubectl "${N[@]}" create configmap dashboards-wind-park --from-file=dashboards/wind-park.json --dry-run=client -o yaml | kubectl "${N[@]}" apply -f - >/dev/null

log "Prometheus, Grafana, Kafka UI"
for f in prometheus grafana kafka-ui; do apply_tpl "$f.yaml" "${N[@]}"; done
for d in prometheus grafana kafka-ui; do kubectl "${N[@]}" rollout status "deployment/$d" --timeout=240s; done
log "Done: Grafana :30300, Prometheus :30900, Kafka UI :30800 on any node"
