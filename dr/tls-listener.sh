#!/usr/bin/env bash
# Rescue path of the extra task: adds the listener `externaltls` (NodePort 31194, TLS, no client authentication) to
# the Kafka cluster, the same block the lab adds to cluster/nordwind-kafka.yaml. Rolls the brokers once. Run it on
# node1. Idempotent: a cluster that has the listener already is left alone.
. "$(dirname "$0")/../lib/common.sh"
need kubectl; need python3
kube_ready || die "kubectl cannot reach the cluster."
N=(-n "$KAFKA_NAMESPACE")
kubectl "${N[@]}" get kafka "$KAFKA_CLUSTER" >/dev/null 2>&1 || die "Kafka cluster is missing. Run cluster/prepare.sh first."

if kubectl "${N[@]}" get kafka "$KAFKA_CLUSTER" -o jsonpath='{.spec.kafka.listeners[*].name}' | tr ' ' '\n' | grep -qx externaltls; then
  echo "The listener externaltls exists already."
else
  log "Adding the listener externaltls (rolling update)"
  kubectl "${N[@]}" patch kafka "$KAFKA_CLUSTER" --type json -p '[{"op":"add","path":"/spec/kafka/listeners/-","value":
    {"name":"externaltls","port":9095,"type":"nodeport","tls":true,"configuration":{
      "preferredNodePortAddressType":"InternalIP","bootstrap":{"nodePort":31194},
      "brokers":[{"broker":0,"nodePort":31195},{"broker":1,"nodePort":31196},{"broker":2,"nodePort":31197}]}}}]' >/dev/null
  sleep 10
fi
kubectl "${N[@]}" wait "kafka/${KAFKA_CLUSTER}" --for=condition=Ready --timeout=1200s >/dev/null
kubectl "${N[@]}" get kafka "$KAFKA_CLUSTER" -o jsonpath='{.status.listeners[?(@.name=="externaltls")].bootstrapServers}{"\n"}'
