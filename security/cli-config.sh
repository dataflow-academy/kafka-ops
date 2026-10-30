#!/usr/bin/env bash
# Writes the client settings for the Kafka tools on the host, for the listener external with TLS and SCRAM:
#
#   ./cli-config.sh      creates the user platform if needed, writes security/platform.properties and platform-ca.crt
#
# Use it with  kafka-topics.sh --bootstrap-server $IP.1:31094 --command-config ~/kafka-ops/security/platform.properties --list
# The host name check is off: the tools connect to the private address, the certificate names the public one.
. "$(dirname "$0")/../lib/common.sh"
need kubectl
N=(-n "$KAFKA_NAMESPACE")
HERE="$(cd "$(dirname "$0")" && pwd)"
kubectl apply -f "$HERE/examples/platform.yaml"
kubectl "${N[@]}" wait kafkauser/platform --for=condition=Ready --timeout=120s >/dev/null
kubectl "${N[@]}" get secret "${KAFKA_CLUSTER}-cluster-ca-cert" -o 'jsonpath={.data.ca\.crt}' | base64 -d > "$HERE/platform-ca.crt"
umask 077
cat > "$HERE/platform.properties" <<PROPS
security.protocol=SASL_SSL
sasl.mechanism=SCRAM-SHA-512
sasl.jaas.config=$(kubectl "${N[@]}" get secret platform -o 'jsonpath={.data.sasl\.jaas\.config}' | base64 -d)
ssl.truststore.type=PEM
ssl.truststore.location=$HERE/platform-ca.crt
ssl.endpoint.identification.algorithm=
PROPS
echo "Written: $HERE/platform.properties"
