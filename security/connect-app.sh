#!/usr/bin/env bash
# Connects a team's application with its Kafka user, the same change the lab makes by hand for the control room:
# creates the KafkaUser without ACLs if it does not exist yet (an identity only: with allow.everyone.if.no.acl.found
# the application may still use every resource without ACLs), copies the Secrets into the team's namespace
# (copy-secrets.sh) and sets the bootstrap address and six client settings on the Deployment, so that the application
# connects with mutual TLS to the tls listener.
#
#   ./connect-app.sh <deployment> <user> [namespace]      e.g.  ./connect-app.sh scada-telemetry scada
#
# The settings are plain client configs. They go into the Deployment's env, which wins over its ConfigMap:
#   BOOTSTRAP_SERVERS  ...:9093      KAFKA_SECURITY_PROTOCOL=SSL
#   KAFKA_SSL_KEYSTORE_TYPE=PEM      KAFKA_SSL_KEYSTORE_CERTIFICATE_CHAIN / KAFKA_SSL_KEYSTORE_KEY  (user.crt / user.key)
#   KAFKA_SSL_TRUSTSTORE_TYPE=PEM    KAFKA_SSL_TRUSTSTORE_CERTIFICATES                              (cluster CA)
# `kubectl describe deployment <deployment> -n <namespace>` shows them afterwards.
. "$(dirname "$0")/../lib/common.sh"
need kubectl
deploy="${1:?usage: connect-app.sh <deployment> <user> [namespace]}"; user="${2:?}"; ns="${3:-windpark}"

kubectl -n "$ns" get deployment "$deploy" >/dev/null || die "No Deployment '$deploy' in the namespace $ns."
if ! kubectl -n "$KAFKA_NAMESPACE" get kafkauser "$user" >/dev/null 2>&1; then
  printf 'apiVersion: kafka.strimzi.io/v1\nkind: KafkaUser\nmetadata:\n  name: %s\n  namespace: %s\n  labels:\n    strimzi.io/cluster: %s\nspec:\n  authentication:\n    type: tls\n' \
    "$user" "$KAFKA_NAMESPACE" "$KAFKA_CLUSTER" | kubectl apply -f -
  echo "KafkaUser $user created without ACLs"
fi
kubectl -n "$KAFKA_NAMESPACE" wait "kafkauser/$user" --for=condition=Ready --timeout=120s >/dev/null
"$(dirname "$0")/copy-secrets.sh" "$user" "$ns"

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
