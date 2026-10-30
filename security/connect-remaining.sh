#!/usr/bin/env bash
# Connects the teams that have no user yet, so that nothing is left on a plaintext listener: Alerts, Assets and
# Maintenance each get a KafkaUser without ACLs and the certificate.
#
#   ./connect-remaining.sh
#
# Their clients differ from the Java applications of connect-app.sh: Assets is a librdkafka client with other setting
# names, Alerts and the Maintenance CronJob run the console producer, which reads its settings from a file. So the
# command of those two first writes that file into /tmp from the environment.
. "$(dirname "$0")/../lib/common.sh"
need kubectl; need python3
ns=windpark
HERE="$(cd "$(dirname "$0")" && pwd)"
bootstrap="${KAFKA_CLUSTER}-kafka-bootstrap.${KAFKA_NAMESPACE}.svc:9093"

create_user() {
  printf 'apiVersion: kafka.strimzi.io/v1\nkind: KafkaUser\nmetadata:\n  name: %s\n  namespace: %s\n  labels:\n    strimzi.io/cluster: %s\nspec:\n  authentication:\n    type: tls\n' \
    "$1" "$KAFKA_NAMESPACE" "$KAFKA_CLUSTER" | kubectl apply -f -
  kubectl -n "$KAFKA_NAMESPACE" wait "kafkauser/$1" --for=condition=Ready --timeout=120s >/dev/null
  "$HERE/copy-secrets.sh" "$1" "$ns"
}

log "Assets"
create_user assets
kubectl -n "$ns" patch deployment assets-masterdata --type strategic -p "$(python3 - <<PY
import json
secret = lambda n, s, k: {"name": n, "valueFrom": {"secretKeyRef": {"name": s, "key": k}}}
print(json.dumps({"spec": {"template": {"spec": {"containers": [{"name": "producer", "env": [
    {"name": "BOOTSTRAP_SERVERS", "value": "$bootstrap"},
    {"name": "KAFKA_SECURITY_PROTOCOL", "value": "SSL"},
    secret("KAFKA_SSL_CERTIFICATE_PEM", "kafka-user-assets", "user.crt"),
    secret("KAFKA_SSL_KEY_PEM", "kafka-user-assets", "user.key"),
    secret("KAFKA_SSL_CA_PEM", "kafka-cluster-ca", "ca.crt"),
]}]}}}}))
PY
)"
kubectl -n "$ns" rollout status deployment/assets-masterdata --timeout=180s

# Console producer: the PEM values go into the properties file on one line, with \n for the line breaks.
console_patch() {  # console_patch <kind> <name> <user>
  # The shell variables in the Python string belong to the command written into the workload.
  # shellcheck disable=SC2016
  kubectl -n "$ns" get "$1" "$2" -o json | USER_NAME="$3" BOOTSTRAP="$bootstrap" python3 -c '
import json, os, sys
obj = json.load(sys.stdin)
cron = obj["kind"] == "CronJob"
pod = obj["spec"]["jobTemplate"]["spec"]["template"] if cron else obj["spec"]["template"]
container = pod["spec"]["containers"][0]
script = container["command"][-1]
if "client.properties" not in script:
    script = r"""oneline() { printf %s "$1" | sed -z "s/\n/\\\\n/g"; }
{
  echo security.protocol=SSL
  echo ssl.keystore.type=PEM
  echo "ssl.keystore.certificate.chain=$(oneline "$TLS_CERT")"
  echo "ssl.keystore.key=$(oneline "$TLS_KEY")"
  echo ssl.truststore.type=PEM
  echo "ssl.truststore.certificates=$(oneline "$TLS_CA")"
} > /tmp/client.properties
""" + script.replace("--topic \"$TOPIC\"", "--topic \"$TOPIC\" --producer.config /tmp/client.properties")
secret = lambda n, s, k: {"name": n, "valueFrom": {"secretKeyRef": {"name": s, "key": k}}}
user = "kafka-user-" + os.environ["USER_NAME"]
env = [{"name": "BOOTSTRAP_SERVERS", "value": os.environ["BOOTSTRAP"]},
       secret("TLS_CERT", user, "user.crt"), secret("TLS_KEY", user, "user.key"),
       secret("TLS_CA", "kafka-cluster-ca", "ca.crt")]
patch = {"spec": {"template": {"spec": {"containers": [{"name": container["name"], "env": env,
                                                        "command": container["command"][:-1] + [script]}]}}}}
if cron:
    patch = {"spec": {"jobTemplate": patch}}
print(json.dumps(patch))' | kubectl -n "$ns" patch "$1" "$2" --type strategic --patch-file /dev/stdin
}

log "Alerts"
create_user alerts
console_patch deployment alerts alerts
kubectl -n "$ns" rollout status deployment/alerts --timeout=180s

log "Maintenance"
create_user maintenance
console_patch cronjob maintenance-report maintenance
