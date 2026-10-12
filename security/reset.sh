#!/usr/bin/env bash
# Back to the open cluster: no users, no authorization, no authentication on the tls listener, applications
# without client certificates. Rolls the cluster once if security was on. Run it on node1. Idempotent.
. "$(dirname "$0")/../lib/common.sh"
need kubectl
kube_ready || { echo "No cluster reachable, nothing to reset."; exit 0; }
N=(-n "$KAFKA_NAMESPACE")
kubectl "${N[@]}" get kafka "$KAFKA_CLUSTER" >/dev/null 2>&1 || { echo "No Kafka cluster, nothing to reset."; exit 0; }

log "Users and the copies of their Secrets"
kubectl "${N[@]}" delete kafkauser --all --ignore-not-found >/dev/null
for s in $(kubectl -n windpark get secret -o name 2>/dev/null | grep -E 'kafka-user-|kafka-cluster-ca' || true); do
  kubectl -n windpark delete "$s" --ignore-not-found >/dev/null
done

ops=()
[ -n "$(kubectl "${N[@]}" get kafka "$KAFKA_CLUSTER" -o jsonpath='{.spec.kafka.authorization.type}')" ] \
  && ops+=('{"op":"remove","path":"/spec/kafka/authorization"}')
# The tls listener is the second one in cluster/kafka.yaml; find it by name rather than by position.
idx="$(kubectl "${N[@]}" get kafka "$KAFKA_CLUSTER" -o json | python3 -c '
import json, sys
for i, l in enumerate(json.load(sys.stdin)["spec"]["kafka"]["listeners"]):
    if l["name"] == "tls" and l.get("authentication"):
        print(i)')"
[ -n "$idx" ] && ops+=("{\"op\":\"remove\",\"path\":\"/spec/kafka/listeners/$idx/authentication\"}")
if [ ${#ops[@]} -gt 0 ]; then
  log "Switching authorization and authentication off (rolling update)"
  patch="[$(IFS=,; echo "${ops[*]}")]"
  kubectl "${N[@]}" patch kafka "$KAFKA_CLUSTER" --type json -p "$patch" >/dev/null
  sleep 10
  kubectl "${N[@]}" wait "kafka/${KAFKA_CLUSTER}" --for=condition=Ready --timeout=1200s
fi

if kubectl get namespace windpark >/dev/null 2>&1; then
  log "Applications without client certificates"
  kubectl -n windpark delete deployment -l app.kubernetes.io/part-of=wind-park --ignore-not-found >/dev/null
  "$(dirname "$0")/../windpark/prepare.sh" healthy
fi
