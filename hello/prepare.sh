#!/usr/bin/env bash
# Start state "first lab done": three-node k3s, the Strimzi operator, and the small cluster `hello`
# with the topic `hello` and one message in it. Run it on node1. Idempotent.
. "$(dirname "$0")/../lib/common.sh"
need kubectl
HERE="$(cd "$(dirname "$0")" && pwd)"
"$ROOT/k3s/prepare.sh"
"$ROOT/cluster/operator.sh"
log "Cluster hello"
kubectl apply -f "$HERE/hello.yaml"
kubectl -n "$KAFKA_NAMESPACE" wait kafka/hello --for=condition=Ready --timeout=300s
kubectl -n "$KAFKA_NAMESPACE" get kafkatopic hello >/dev/null 2>&1 || kubectl apply -f - <<'YAML'
apiVersion: kafka.strimzi.io/v1
kind: KafkaTopic
metadata:
  name: hello
  namespace: kafka
  labels: { strimzi.io/cluster: hello }
spec:
  partitions: 1
  replicas: 1
YAML
kubectl -n "$KAFKA_NAMESPACE" wait kafkatopic/hello --for=condition=Ready --timeout=120s
kubectl -n "$KAFKA_NAMESPACE" exec hello-single-0 -- bash -c \
  'echo "Windrad alpha-ventus-07 meldet sich" | /opt/kafka/bin/kafka-console-producer.sh --bootstrap-server localhost:9092 --topic hello'
