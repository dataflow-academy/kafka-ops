#!/usr/bin/env bash
# Connects Kafka UI with its own Kafka user: creates the KafkaUser kafka-ui (examples/kafka-ui.yaml, no ACLs) and moves
# Kafka UI to the tls listener with the user's certificate. The cluster must name it as a super user
# (spec.kafka.authorization.superUsers: CN=kafka-ui), or it sees nothing that has ACLs.
#
#   ./connect-kafka-ui.sh
#
# Kafka UI runs in the namespace kafka, next to the Secrets of the User Operator, so nothing is copied. Its client
# settings are environment variables KAFKA_CLUSTERS_0_PROPERTIES_<setting>, e.g. ..._SECURITY_PROTOCOL=SSL.
# reset.sh puts it back on the plain listener.
. "$(dirname "$0")/../lib/common.sh"
need kubectl
N=(-n "$KAFKA_NAMESPACE")
kubectl apply -f "$(dirname "$0")/examples/kafka-ui.yaml"
kubectl "${N[@]}" wait kafkauser/kafka-ui --for=condition=Ready --timeout=120s >/dev/null

p=KAFKA_CLUSTERS_0_PROPERTIES
secret_env() { printf '{"name":"%s","valueFrom":{"secretKeyRef":{"name":"%s","key":"%s"}}}' "$1" "$2" "$3"; }
patch="{\"spec\":{\"template\":{\"spec\":{\"containers\":[{\"name\":\"kafka-ui\",\"env\":[
 {\"name\":\"KAFKA_CLUSTERS_0_BOOTSTRAPSERVERS\",\"value\":\"${KAFKA_CLUSTER}-kafka-bootstrap:9093\"},
 {\"name\":\"${p}_SECURITY_PROTOCOL\",\"value\":\"SSL\"},
 {\"name\":\"${p}_SSL_KEYSTORE_TYPE\",\"value\":\"PEM\"},
 $(secret_env "${p}_SSL_KEYSTORE_CERTIFICATE_CHAIN" kafka-ui user.crt),
 $(secret_env "${p}_SSL_KEYSTORE_KEY" kafka-ui user.key),
 {\"name\":\"${p}_SSL_TRUSTSTORE_TYPE\",\"value\":\"PEM\"},
 $(secret_env "${p}_SSL_TRUSTSTORE_CERTIFICATES" "${KAFKA_CLUSTER}-cluster-ca-cert" ca.crt)
]}]}}}}"
kubectl "${N[@]}" patch deployment kafka-ui --type strategic -p "$patch"
kubectl "${N[@]}" rollout status deployment/kafka-ui --timeout=180s
