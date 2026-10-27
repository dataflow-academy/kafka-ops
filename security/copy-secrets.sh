#!/usr/bin/env bash
# Copies the Secret of a Kafka user and the certificate of the cluster CA into a team's namespace: a Pod can only
# use Secrets of its own namespace, the User Operator writes them into the namespace kafka.
#
#   ./copy-secrets.sh <user> [namespace]      e.g.  ./copy-secrets.sh control-room
#
# Creates kafka-user-<user> (user.crt, user.key) and kafka-cluster-ca (ca.crt) in the namespace (default windpark).
# The copies carry only the data, no labels and no owner: the owner (the KafkaUser) lives in another namespace.
# In production a secrets tool or the team's pipeline does this.
. "$(dirname "$0")/../lib/common.sh"
need kubectl; need python3
user="${1:?usage: copy-secrets.sh <user> [namespace]}"; ns="${2:-windpark}"

copy_secret() {  # copy_secret <name in kafka> <name in the team namespace>
  kubectl -n "$KAFKA_NAMESPACE" get secret "$1" -o json | python3 -c '
import json, sys
s = json.load(sys.stdin)
json.dump({"apiVersion": "v1", "kind": "Secret", "type": "Opaque",
           "metadata": {"name": sys.argv[1], "namespace": sys.argv[2]}, "data": s["data"]}, sys.stdout)' "$2" "$ns" \
    | kubectl apply -f -
}
kubectl -n "$KAFKA_NAMESPACE" get secret "$user" >/dev/null 2>&1 || die "No Secret '$user' in $KAFKA_NAMESPACE: is the KafkaUser there and Ready?"
copy_secret "$user" "kafka-user-$user"
copy_secret "${KAFKA_CLUSTER}-cluster-ca-cert" kafka-cluster-ca
