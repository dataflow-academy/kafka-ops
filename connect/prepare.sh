#!/usr/bin/env bash
# Start state for the Connect lab: the Kafka cluster is open and Ready, the registry runs in the cluster and
# the nodes can pull from it, the maintenance team's PostgreSQL runs with its table, and the topic for the work
# orders exists. No Kafka Connect, no connectors. Run it on node1.
. "$(dirname "$0")/../lib/common.sh"
need kubectl
kube_ready || die "kubectl cannot reach the cluster."
HERE="$(cd "$(dirname "$0")/.." && pwd)"
N=(-n "$KAFKA_NAMESPACE")
kubectl "${N[@]}" get kafka "$KAFKA_CLUSTER" >/dev/null 2>&1 || die "Kafka cluster is missing. Run cluster/prepare.sh first."
if [ -n "$(kubectl "${N[@]}" get kafka "$KAFKA_CLUSTER" -o jsonpath='{.spec.kafka.authorization.type}')" ]; then
  log "Authorization is on (security lab): users and ACLs go, everyone may connect again"
  "$HERE/security/reset.sh" --keep-authorization
fi
"$(dirname "$0")/reset.sh"

log "Registry"
kubectl apply -f "$(dirname "$0")/registry.yaml"
kubectl -n registry rollout status deployment/registry --timeout=180s
"$(dirname "$0")/registry-mirror.sh"

log "PostgreSQL of the maintenance team"
kubectl apply -f "$(dirname "$0")/postgres.yaml"
kubectl "${N[@]}" rollout status deployment/maintenance-db --timeout=300s
kubectl apply -f "$(dirname "$0")/topic.yaml"
kubectl "${N[@]}" wait kafkatopic/maintenance-work-orders --for=condition=Ready --timeout=120s
kubectl "${N[@]}" wait "kafka/${KAFKA_CLUSTER}" --for=condition=Ready --timeout=300s
log "Done"
