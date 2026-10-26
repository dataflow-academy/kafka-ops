#!/usr/bin/env bash
# Start state "first lab done up to the cleanup": three-node k3s, the Strimzi operator, Kafka UI, and the small
# cluster `hello` with the topic `hello` and one message in it. Run it on node1. Idempotent.
. "$(dirname "$0")/../lib/common.sh"
HERE="$(cd "$(dirname "$0")" && pwd)"
# k3s brings kubectl.
"$ROOT/k3s/prepare.sh"
"$ROOT/cluster/operator.sh"
log "Cluster hello"
kubectl apply -f "$HERE/hello.yaml"
kubectl -n "$KAFKA_NAMESPACE" wait kafka/hello --for=condition=Ready --timeout=300s
kubectl apply -f "$HERE/topic.yaml"
kubectl -n "$KAFKA_NAMESPACE" wait kafkatopic/hello --for=condition=Ready --timeout=120s
kubectl -n "$KAFKA_NAMESPACE" exec hello-single-0 -c kafka -- bash -c \
  'echo "Windrad alpha-ventus-07 meldet sich" | /opt/kafka/bin/kafka-console-producer.sh --bootstrap-server localhost:9092 --topic hello'
log "Kafka UI"
kubectl apply -f "$ROOT/kafka-ui/kafka-ui.yaml"
kubectl -n "$KAFKA_NAMESPACE" rollout status deployment/kafka-ui --timeout=180s
