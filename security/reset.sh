#!/usr/bin/env bash
# Takes the security lab back. Run it on node1. Idempotent.
#
#   ./reset.sh                       back to the open cluster before the lab: no users, no authorization, no
#                                    authentication on the tls listener, no allow.everyone.if.no.acl.found, applications
#                                    and Kafka UI without client certificates. Rolls the cluster once if security was on.
#   ./reset.sh --keep-authorization  for the other labs: the users (and with them every ACL) and the copies of their
#                                    Secrets go, the applications and Kafka UI go back to the plain listener.
#                                    Authorization and the tls listener stay as they are, so the cluster file of the groups still matches; with
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
rm -f "$ROOT/security/platform.properties" "$ROOT/security/platform-ca.crt"
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
# The lab ends with the plaintext listeners switched off; every start state needs them back.
names = [listener["name"] for listener in kafka.get("listeners", [])]
if "plain" not in names:
    ops.append({"op": "add", "path": "/spec/kafka/listeners/-", "value":
                {"name": "plain", "port": 9092, "type": "internal", "tls": False}})
if "external" not in names:
    ops.append({"op": "add", "path": "/spec/kafka/listeners/-", "value":
                {"name": "external", "port": 9094, "type": "nodeport", "tls": False, "configuration": {
                    "preferredNodePortAddressType": "InternalIP", "bootstrap": {"nodePort": 31094},
                    "brokers": [{"broker": b, "nodePort": 31095 + b} for b in range(3)]}}})
else:
    # The lab puts the listener external on TLS with SCRAM.
    i = names.index("external")
    if kafka["listeners"][i].get("tls"):
        ops.append({"op": "replace", "path": "/spec/kafka/listeners/%d/tls" % i, "value": False})
    if kafka["listeners"][i].get("authentication"):
        ops.append({"op": "remove", "path": "/spec/kafka/listeners/%d/authentication" % i})
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
  else log "Open for everyone again: plaintext listeners, allow.everyone.if.no.acl.found=true (rolling update)"; fi
  kubectl "${N[@]}" patch kafka "$KAFKA_CLUSTER" --type json -p "$ops" >/dev/null
  # The labs change the cluster through this file: it has to say the same, or the next apply closes the cluster again.
  file="$ROOT/cluster/nordwind-kafka.yaml"
  if [ "$MODE" = keep ] && [ -e "$file" ] && grep -qE '^\s*allow\.everyone\.if\.no\.acl\.found:\s*"?false' "$file"; then
    sed -i -E 's/^(\s*allow\.everyone\.if\.no\.acl\.found:\s*)"?false"?/\1true/' "$file"
    echo "cluster/nordwind-kafka.yaml: allow.everyone.if.no.acl.found is true again"
  fi
  if [ -e "$file" ]; then
    python3 - "$file" <<'PY'
import re, sys
path = sys.argv[1]
lines = open(path).read().split("\n")
# The listener external: tls false, no authentication.
out, indent, skip = [], None, None
for line in lines:
    width = len(line) - len(line.lstrip())
    if skip is not None:
        if line.strip() and width > skip:
            continue
        skip = None
    if re.match(r"\s*- name: ", line):
        indent = width if line.strip() == "- name: external" else None
    elif indent is not None and line.strip() and width <= indent:
        indent = None
    if indent is not None and width == indent + 2:
        if line.strip() == "tls: true":
            line = line.replace("true", "false")
        elif line.strip() == "authentication:":
            skip = width
            continue
    out.append(line)
text = "\n".join(out)
def block(body):
    return "".join(pad + b + "\n" for b in body.splitlines())
# Same indentation as the entries already in the list.
pad = re.search(r"^ *listeners:\n( *)- ", text, re.M).group(1)
add = ""
if not re.search(r"^\s*- name: plain$", text, re.M):
    add += block("- name: plain\n  port: 9092\n  type: internal\n  tls: false")
if not re.search(r"^\s*- name: external$", text, re.M):
    add += block("""- name: external
  port: 9094
  type: nodeport
  tls: false
  configuration:
    preferredNodePortAddressType: InternalIP
    bootstrap:
      nodePort: 31094
    brokers:
      - broker: 0
        nodePort: 31095
      - broker: 1
        nodePort: 31096
      - broker: 2
        nodePort: 31097""")
text = re.sub(r"^( *listeners:\n)", lambda m: m.group(1) + add, text, count=1, flags=re.M)
open(path, "w").write(text)
PY
  fi
  sleep 10
  kubectl "${N[@]}" wait "kafka/${KAFKA_CLUSTER}" --for=condition=Ready --timeout=1200s
fi

# Kafka UI on the tls listener (connect-kafka-ui.sh) has lost its user with the Secret: back to plain.
if kubectl "${N[@]}" get deployment kafka-ui -o yaml 2>/dev/null | grep -q ':9093'; then
  log "Kafka UI back on the plain listener"
  kubectl "${N[@]}" delete deployment kafka-ui --ignore-not-found >/dev/null
  kubectl apply -f "$ROOT/kafka-ui/kafka-ui.yaml" >/dev/null
  kubectl "${N[@]}" rollout status deployment/kafka-ui --timeout=180s >/dev/null
fi

if kubectl get namespace windpark >/dev/null 2>&1; then
  # Only applications that were moved to the tls listener have to go back (keep); the full reset always rebuilds them.
  if [ "$MODE" = full ] || kubectl -n windpark get deployment,configmap -o yaml | grep -qE ':9093|KAFKA_SECURITY_PROTOCOL'; then
    log "Applications without client certificates"
    kubectl -n windpark delete deployment,cronjob -l app.kubernetes.io/part-of=wind-park --ignore-not-found >/dev/null
    "$(dirname "$0")/../windpark/prepare.sh" healthy
  fi
fi
