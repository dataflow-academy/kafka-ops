#!/usr/bin/env bash
# Tries one operation as a Kafka user and says whether the cluster allowed it.
#
#   ./probe.sh <user> produce <topic>
#   ./probe.sh <user> consume <topic> [group]
#
# The user's certificate and the cluster CA are read from their Secrets in the namespace kafka and used
# for a mutual-TLS connection to the tls listener, from a console client inside a broker pod. Prints
# ALLOWED or DENIED (with the reason) and exits 0 or 1. For consume, the default group is the user's name.
. "$(dirname "$0")/../lib/common.sh"
need kubectl
user="${1:?usage: probe.sh <user> produce|consume <topic> [group]}"; op="${2:?}"; topic="${3:?}"; group="${4:-$user}"
N=(-n "$KAFKA_NAMESPACE")
pod="${CLIENT_POD:-${KAFKA_CLUSTER}-broker-0}"
pem() { kubectl "${N[@]}" get secret "$1" -o "jsonpath={.data.$2}" | base64 -d | awk '{printf "%s\\n", $0}'; }

props="security.protocol=SSL
ssl.keystore.type=PEM
ssl.keystore.certificate.chain=$(pem "$user" user\\.crt)
ssl.keystore.key=$(pem "$user" user\\.key)
ssl.truststore.type=PEM
ssl.truststore.certificates=$(pem "${KAFKA_CLUSTER}-cluster-ca-cert" ca\\.crt)"
file="/tmp/probe-$user.properties"
printf '%s\n' "$props" | kubectl "${N[@]}" exec -i "$pod" -c kafka -- sh -c "cat > $file"
bootstrap="${KAFKA_CLUSTER}-kafka-bootstrap:9093"

case "$op" in
  produce)
    out="$(echo "probe from $user" | kubectl "${N[@]}" exec -i "$pod" -c kafka -- timeout 40 bin/kafka-console-producer.sh \
      --bootstrap-server "$bootstrap" --producer.config "$file" --topic "$topic" 2>&1 || true)" ;;
  consume)
    out="$(kubectl "${N[@]}" exec "$pod" -c kafka -- timeout 40 bin/kafka-console-consumer.sh \
      --bootstrap-server "$bootstrap" --consumer.config "$file" --topic "$topic" --group "$group" \
      --consumer-property enable.auto.commit=false --from-beginning --max-messages 1 --timeout-ms 20000 2>&1 || true)" ;;
  *) die "Operation must be produce or consume." ;;
esac
kubectl "${N[@]}" exec "$pod" -c kafka -- rm -f "$file"

if echo "$out" | grep -qE 'AuthorizationException|Not authorized|SSLHandshake|TOPIC_AUTHORIZATION_FAILED|GROUP_AUTHORIZATION_FAILED'; then
  echo "DENIED: $user cannot $op $topic"
  echo "$out" | grep -E 'AuthorizationException|Not authorized|SSLHandshake' | head -2 | cut -c1-200
  exit 1
fi
if [ "$op" = consume ] && ! echo "$out" | grep -q 'Processed a total of 1 messages'; then
  echo "NO DATA: $user connected but read nothing from $topic"; echo "$out" | tail -3 | cut -c1-200; exit 2
fi
echo "ALLOWED: $user can $op $topic"
