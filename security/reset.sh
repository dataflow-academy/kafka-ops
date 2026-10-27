#!/usr/bin/env bash
# Takes the security lab back. Run it on node1. Idempotent.
#
#   ./reset.sh                       back to the open cluster before the lab: no users, no authorization, no
#                                    authentication on the tls listener, no allow.everyone.if.no.acl.found, applications
#                                    without client certificates. Rolls the cluster once if security was on.
#   ./reset.sh --keep-authorization  for the labs after it: the users (and with them every ACL) and the copies of their
#                                    Secrets go, the applications go back to the plain listener. Authorization and the
#                                    tls listener stay as they are, so the cluster file of the groups still matches; with
#                                    allow.everyone.if.no.acl.found=true and no ACL left it lets everyone through. A
#                                    cluster without that setting gets it back (one rolling update), and a `false`
#                                    in cluster/nordwind-kafka.yaml becomes `true`.
. "$(dirname "$0")/../lib/common.sh"
need kubectl; need python3
MODE=full
case "${1:-}" in
  "") ;;
  --keep-authorization) MODE=keep ;;
  *) die "Usage: reset.sh [--keep-authorization]" ;;
esac
kube_ready || { echo "No cluster reachable, nothing to reset."; exit 0; }
N=(-n "$KAFKA_NAMESPACE")
kubectl "${N[@]}" get kafka "$KAFKA_CLUSTER" >/dev/null 2>&1 || { echo "No Kafka cluster, nothing to reset."; exit 0; }

log "Users and the copies of their Secrets"
kubectl "${N[@]}" delete kafkauser --all --ignore-not-found >/dev/null
for s in $(kubectl -n windpark get secret -o name 2>/dev/null | grep -E 'kafka-user-|kafka-cluster-ca' || true); do
  kubectl -n windpark delete "$s" --ignore-not-found >/dev/null
done

kafka_json="$(kubectl "${N[@]}" get kafka "$KAFKA_CLUSTER" -o json)"
# JSON patch operations that take security back (full) or make an authorizing cluster open again (keep).
ops="$(MODE="$MODE" python3 -c '
import json, os, sys
kafka = json.load(sys.stdin)["spec"]["kafka"]
config = kafka.get("config") or {}
key = "allow.everyone.if.no.acl.found"
ops = []
if os.environ["MODE"] == "full":
    if kafka.get("authorization"):
        ops.append({"op": "remove", "path": "/spec/kafka/authorization"})
    if key in config:
        ops.append({"op": "remove", "path": "/spec/kafka/config/" + key})
    for i, listener in enumerate(kafka.get("listeners", [])):
        if listener["name"] == "tls" and listener.get("authentication"):
            ops.append({"op": "remove", "path": "/spec/kafka/listeners/%d/authentication" % i})
elif kafka.get("authorization") and str(config.get(key)).lower() != "true":
    if "config" not in kafka:
        ops.append({"op": "add", "path": "/spec/kafka/config", "value": {}})
    ops.append({"op": "add", "path": "/spec/kafka/config/" + key, "value": True})
print(json.dumps(ops) if ops else "")' <<<"$kafka_json")"
if [ -n "$ops" ]; then
  if [ "$MODE" = full ]; then log "Switching authorization and authentication off (rolling update)"
  else log "Authorization without ACLs lets everyone through again: allow.everyone.if.no.acl.found=true (rolling update)"; fi
  kubectl "${N[@]}" patch kafka "$KAFKA_CLUSTER" --type json -p "$ops" >/dev/null
  # The labs change the cluster through this file: it has to say the same, or the next apply closes the cluster again.
  file="$ROOT/cluster/nordwind-kafka.yaml"
  if [ "$MODE" = keep ] && [ -e "$file" ] && grep -qE '^\s*allow\.everyone\.if\.no\.acl\.found:\s*"?false' "$file"; then
    sed -i -E 's/^(\s*allow\.everyone\.if\.no\.acl\.found:\s*)"?false"?/\1true/' "$file"
    echo "cluster/nordwind-kafka.yaml: allow.everyone.if.no.acl.found is true again"
  fi
  sleep 10
  kubectl "${N[@]}" wait "kafka/${KAFKA_CLUSTER}" --for=condition=Ready --timeout=1200s
fi

if kubectl get namespace windpark >/dev/null 2>&1; then
  # Only applications that were moved to the tls listener have to go back (keep); the full reset always rebuilds them.
  if [ "$MODE" = full ] || kubectl -n windpark get deployment,configmap -o yaml | grep -qE ':9093|KAFKA_SECURITY_PROTOCOL'; then
    log "Applications without client certificates"
    kubectl -n windpark delete deployment -l app.kubernetes.io/part-of=wind-park --ignore-not-found >/dev/null
    "$(dirname "$0")/../windpark/prepare.sh" healthy
  fi
fi
