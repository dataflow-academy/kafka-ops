#!/usr/bin/env bash
# Removes the second cluster and everything the multi-cluster lab changes: the mirror, the namespace kafka-dr,
# the extra namespace of the operator, and the wind park applications go back to the first cluster.
# If the first cluster was "lost" (operator scaled to 0), it comes back. Run it on node1. Idempotent.
. "$(dirname "$0")/../lib/common.sh"
need kubectl; need python3
kube_ready || { echo "No cluster reachable, nothing to reset."; exit 0; }
OP=(-n "$KAFKA_NAMESPACE")
kubectl "${OP[@]}" get deployment strimzi-cluster-operator >/dev/null 2>&1 || { echo "No operator, nothing to reset."; exit 0; }

if [ "$(kubectl "${OP[@]}" get deployment strimzi-cluster-operator -o jsonpath='{.spec.replicas}')" = 0 ]; then
  log "Bringing the operator (and with it the first cluster) back"
  kubectl "${OP[@]}" scale deployment strimzi-cluster-operator --replicas=1
  kubectl "${OP[@]}" rollout status deployment/strimzi-cluster-operator --timeout=180s
fi

if kubectl get namespace kafka-dr >/dev/null 2>&1; then
  log "Deleting the second cluster"
  kubectl -n kafka-dr delete kafkamirrormaker2 --all --ignore-not-found --timeout=120s >/dev/null || true
  kubectl -n kafka-dr delete kafka --all --ignore-not-found --timeout=300s >/dev/null || true
  kubectl delete namespace kafka-dr --ignore-not-found --timeout=300s
fi

current="$(kubectl "${OP[@]}" get deployment strimzi-cluster-operator -o jsonpath='{.spec.template.spec.containers[0].env[?(@.name=="STRIMZI_NAMESPACE")].value}')"
if [ -n "$current" ]; then
  log "The operator watches only ${KAFKA_NAMESPACE} again"
  idx="$(kubectl "${OP[@]}" get deployment strimzi-cluster-operator -o json | python3 -c '
import json, sys
env = json.load(sys.stdin)["spec"]["template"]["spec"]["containers"][0]["env"]
print([e["name"] for e in env].index("STRIMZI_NAMESPACE"))')"
  kubectl "${OP[@]}" patch deployment strimzi-cluster-operator --type json -p \
    "[{\"op\":\"replace\",\"path\":\"/spec/template/spec/containers/0/env/$idx\",\"value\":{\"name\":\"STRIMZI_NAMESPACE\",\"valueFrom\":{\"fieldRef\":{\"fieldPath\":\"metadata.namespace\"}}}}]" >/dev/null
  kubectl "${OP[@]}" rollout status deployment/strimzi-cluster-operator --timeout=180s
fi

# The Kafka resource still says Ready after the "disaster": wait for the pods themselves.
all_ready() { [ "$(kubectl "${OP[@]}" get pods -l "strimzi.io/cluster=${KAFKA_CLUSTER},strimzi.io/component-type=kafka" \
  -o jsonpath='{.items[*].status.containerStatuses[0].ready}' | wc -w)" -ge 6 ] \
  && ! kubectl "${OP[@]}" get pods -l "strimzi.io/cluster=${KAFKA_CLUSTER},strimzi.io/component-type=kafka" \
  -o jsonpath='{.items[*].status.containerStatuses[0].ready}' | grep -q false; }
wait_for "the first cluster's pods" 900 all_ready
kubectl "${OP[@]}" wait "kafka/${KAFKA_CLUSTER}" --for=condition=Ready --timeout=900s
if kubectl get namespace windpark >/dev/null 2>&1; then
  log "Wind park back on the first cluster"
  kubectl -n windpark delete deployment -l app.kubernetes.io/part-of=wind-park --ignore-not-found >/dev/null
fi
"$(dirname "$0")/../windpark/prepare.sh" healthy
