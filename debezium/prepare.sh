#!/usr/bin/env bash
# Start state for the Debezium lab: the Kafka cluster is open and Ready, the registry of the Connect lab runs and the
# nodes can pull from it, the SCADA database runs with its tables, its Debezium role and its publication, the feed
# writes to it, and the two CDC topics exist. No Debezium Connect, no connector.
#   ./prepare.sh          that start state (rescue path of the first task)
#   ./prepare.sh running  plus Kafka Connect with the Debezium plugin and the running connector (rescue path of the
#                         second and third task); connect.yaml is then the solution
# Run it on node1.
. "$(dirname "$0")/../lib/common.sh"
need kubectl
kube_ready || die "kubectl cannot reach the cluster."
MODE="${1:-start}"
case "$MODE" in start|running) ;; *) die "Usage: $0 [start|running]" ;; esac
HERE="$(cd "$(dirname "$0")" && pwd)"
N=(-n "$KAFKA_NAMESPACE")
kubectl "${N[@]}" get kafka "$KAFKA_CLUSTER" >/dev/null 2>&1 || die "Kafka cluster is missing. Run cluster/prepare.sh first."
if [ -n "$(kubectl "${N[@]}" get kafka "$KAFKA_CLUSTER" -o jsonpath='{.spec.kafka.authorization.type}')" ]; then
  log "Authorization is on (security lab): users and ACLs go, everyone may connect again"
  "$ROOT/security/reset.sh" --keep-authorization
fi
"$HERE/reset.sh"

log "Registry"
kubectl apply -f "$ROOT/connect/registry.yaml"
kubectl -n registry rollout status deployment/registry --timeout=180s
"$ROOT/connect/registry-mirror.sh"

log "SCADA database and feed"
kubectl apply -f "$HERE/postgres.yaml"
kubectl -n scada rollout status deployment/scada-db --timeout=300s
kubectl -n scada rollout status deployment/scada-feed --timeout=120s
kubectl apply -f "$HERE/topics.yaml"
kubectl "${N[@]}" wait kafkatopic/scada-turbines kafkatopic/scada-readings --for=condition=Ready --timeout=120s
kubectl "${N[@]}" wait "kafka/${KAFKA_CLUSTER}" --for=condition=Ready --timeout=300s

if [ "$MODE" = running ]; then
  log "Kafka Connect with the Debezium plugin (the build takes a few minutes)"
  cp "$HERE/connect-solution.yaml" "$HERE/connect.yaml"
  kubectl apply -f "$HERE/connect.yaml"
  kubectl "${N[@]}" wait kafkaconnect/debezium --for=condition=Ready --timeout=600s
  log "The connector"
  kubectl apply -f "$HERE/connector.yaml"
  kubectl "${N[@]}" wait kafkaconnector/scada-cdc --for=condition=Ready --timeout=180s
fi
log "Done"
