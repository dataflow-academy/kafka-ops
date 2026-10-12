#!/usr/bin/env bash
# Removes the Kafka cluster and the Strimzi operator, including their data and
# CRDs, so that prepare.sh starts from nothing. Run it on node1. Idempotent.
#
# Workload and monitoring live in the same namespace and are removed with it:
# run their prepare.sh again afterwards.
. "$(dirname "$0")/../lib/common.sh"
need kubectl
kube_ready || { echo "No cluster reachable, nothing to reset."; exit 0; }

log "Deleting namespace ${KAFKA_NAMESPACE} (cluster, operator, data)"
# Delete the Kafka resource first, while the operator is still there to clean up.
kubectl -n "$KAFKA_NAMESPACE" delete kafka --all --wait=true --timeout=300s --ignore-not-found 2>/dev/null || true
kubectl delete namespace "$KAFKA_NAMESPACE" --wait=true --timeout=300s --ignore-not-found

log "Deleting Strimzi CRDs and cluster-wide roles"
kubectl get crd -o name | grep -E '\.strimzi\.io$' | xargs -r kubectl delete --ignore-not-found
kubectl get clusterrole,clusterrolebinding -o name | grep -E 'strimzi' | xargs -r kubectl delete --ignore-not-found
rm -f "$HOME/.kafka-bootstrap-servers"
