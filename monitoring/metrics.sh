#!/usr/bin/env bash
# Switches on the metrics of the Kafka cluster: the JMX Prometheus Exporter in every broker and controller
# and the Kafka Exporter (consumer groups). Strimzi rolls the whole cluster once (about 4 minutes).
# Nothing happens if they are on already. The monitoring lab does the same by hand in its cluster file.
. "$(dirname "$0")/../lib/common.sh"
need kubectl
kube_ready || die "kubectl cannot reach the cluster."
N=(-n "$KAFKA_NAMESPACE")
kubectl "${N[@]}" apply -f "$(dirname "$0")/kafka-metrics-config.yaml" >/dev/null
if [ -z "$(kubectl "${N[@]}" get kafka "$KAFKA_CLUSTER" -o jsonpath='{.spec.kafka.metricsConfig.type}')" ] \
   || [ -z "$(kubectl "${N[@]}" get kafka "$KAFKA_CLUSTER" -o jsonpath='{.spec.kafkaExporter}')" ]; then
  log "Metrics of the Kafka cluster (rolling restart)"
  kubectl "${N[@]}" patch kafka "$KAFKA_CLUSTER" --type merge -p '{"spec":{
    "kafka":{"metricsConfig":{"type":"jmxPrometheusExporter","valueFrom":{"configMapKeyRef":{"name":"kafka-metrics","key":"kafka-metrics-config.yml"}}}},
    "kafkaExporter":{"topicRegex":".*","groupRegex":".*"}}}'
  sleep 10
  kubectl "${N[@]}" wait "kafka/${KAFKA_CLUSTER}" --for=condition=Ready --timeout=900s
fi
