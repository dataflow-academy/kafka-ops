#!/usr/bin/env bash
# Hands a Kafka user to a team's application: copies the user's Secret and the cluster CA into the team's
# namespace (a Secret cannot be mounted across namespaces) and sets the bootstrap address and six client settings on the
# Deployment that make the application connect with mutual TLS to the tls listener.
#
#   ./connect-app.sh <deployment> <user> [namespace]      e.g.  ./connect-app.sh control-room control-room
#
# In production the team would do this in its own repository; the settings are plain client configs:
#   BOOTSTRAP_SERVERS  ...:9093      KAFKA_SECURITY_PROTOCOL=SSL
#   KAFKA_SSL_KEYSTORE_TYPE=PEM      KAFKA_SSL_KEYSTORE_CERTIFICATE_CHAIN / KAFKA_SSL_KEYSTORE_KEY  (user.crt / user.key)
#   KAFKA_SSL_TRUSTSTORE_TYPE=PEM    KAFKA_SSL_TRUSTSTORE_CERTIFICATES                              (cluster CA)
. "$(dirname "$0")/../lib/common.sh"
need kubectl; need python3
deploy="${1:?usage: connect-app.sh <deployment> <user> [namespace]}"; user="${2:?}"; ns="${3:-windpark}"

copy_secret() {  # copy_secret <name in kafka> <name in team namespace>
  kubectl -n "$KAFKA_NAMESPACE" get secret "$1" -o json | python3 -c '
import json, sys
s = json.load(sys.stdin)
json.dump({"apiVersion": "v1", "kind": "Secret", "type": "Opaque",
           "metadata": {"name": sys.argv[1], "namespace": sys.argv[2]}, "data": s["data"]}, sys.stdout)' "$2" "$ns" | kubectl apply -f - >/dev/null
}
kubectl -n "$KAFKA_NAMESPACE" get secret "$user" >/dev/null 2>&1 || die "No Secret '$user' in $KAFKA_NAMESPACE: is the KafkaUser there and Ready?"
copy_secret "$user" "kafka-user-$user"
copy_secret "${KAFKA_CLUSTER}-cluster-ca-cert" kafka-cluster-ca

container="$(kubectl -n "$ns" get deployment "$deploy" -o jsonpath='{.spec.template.spec.containers[0].name}')"
secret_env() { printf '{"name":"%s","valueFrom":{"secretKeyRef":{"name":"%s","key":"%s"}}}' "$1" "$2" "$3"; }
patch="{\"spec\":{\"template\":{\"spec\":{\"containers\":[{\"name\":\"$container\",\"env\":[
 {\"name\":\"BOOTSTRAP_SERVERS\",\"value\":\"${KAFKA_CLUSTER}-kafka-bootstrap.${KAFKA_NAMESPACE}.svc:9093\"},
 {\"name\":\"KAFKA_SECURITY_PROTOCOL\",\"value\":\"SSL\"},
 {\"name\":\"KAFKA_SSL_KEYSTORE_TYPE\",\"value\":\"PEM\"},
 $(secret_env KAFKA_SSL_KEYSTORE_CERTIFICATE_CHAIN "kafka-user-$user" user.crt),
 $(secret_env KAFKA_SSL_KEYSTORE_KEY "kafka-user-$user" user.key),
 {\"name\":\"KAFKA_SSL_TRUSTSTORE_TYPE\",\"value\":\"PEM\"},
 $(secret_env KAFKA_SSL_TRUSTSTORE_CERTIFICATES kafka-cluster-ca ca.crt)
]}]}}}}"
kubectl -n "$ns" patch deployment "$deploy" --type strategic -p "$patch"
kubectl -n "$ns" rollout status "deployment/$deploy" --timeout=180s
