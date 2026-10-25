#!/usr/bin/env bash
# Removes the Kafka cluster and the Strimzi operator, including their data and
# CRDs, so that prepare.sh starts from nothing. Run it on node1. Idempotent.
#
# Monitoring and the tools pod live in the same namespace and are removed with it; the
# wind park lives in its own namespace `windpark` (run windpark/reset.sh first). Run the
# prepare.sh scripts again afterwards.
. "$(dirname "$0")/../lib/common.sh"
need kubectl
kube_ready || { echo "No cluster reachable, nothing to reset."; exit 0; }

log "Deleting namespace ${KAFKA_NAMESPACE} (cluster, operator, data)"
# Delete topics and users first: their finalizers need the Entity Operator, which is gone with the
# Kafka resource, and the namespace would hang in Terminating.
kubectl -n "$KAFKA_NAMESPACE" delete kafkatopic,kafkauser --all --ignore-not-found --wait=true --timeout=120s 2>/dev/null || true
# Delete the Kafka resource while the operator is still there to clean up.
kubectl -n "$KAFKA_NAMESPACE" delete kafka --all --wait=true --timeout=300s --ignore-not-found 2>/dev/null || true
kubectl delete namespace "$KAFKA_NAMESPACE" --wait=true --timeout=300s --ignore-not-found

log "Deleting the topic policies of the governance lab (cluster-wide)"
kubectl delete validatingadmissionpolicybinding,validatingadmissionpolicy kafkatopic-naming kafkatopic-limits --ignore-not-found >/dev/null 2>&1 || true

log "Deleting Strimzi CRDs and cluster-wide roles"
kubectl get crd -o name | grep -E '\.strimzi\.io$' | xargs -r kubectl delete --ignore-not-found
kubectl get clusterrole,clusterrolebinding -o name | grep -E 'strimzi' | xargs -r kubectl delete --ignore-not-found
rm -f "$HOME/.kafka-bootstrap-servers"
