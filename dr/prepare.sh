#!/usr/bin/env bash
# Start state for the multi-cluster lab: your cluster with the authorization of the security lab kept as it is
# (allow.everyone.if.no.acl.found, no users and no ACLs left, so the neighbor group's mirror may read anonymously), or
# open; the wind park on the plain listener; no mirror. Anything left from an earlier run is removed (reset.sh).
# Run it on node1.
. "$(dirname "$0")/../lib/common.sh"
need kubectl
kube_ready || die "kubectl cannot reach the cluster."
kubectl -n "$KAFKA_NAMESPACE" get kafka "$KAFKA_CLUSTER" >/dev/null 2>&1 || die "Kafka cluster is missing. Run cluster/prepare.sh first."
HERE="$(cd "$(dirname "$0")/.." && pwd)"
# Users and ACLs of the security lab go, the applications return to the plain listener; authorization stays.
"$HERE/security/reset.sh" --keep-authorization
"$(dirname "$0")/reset.sh"
kubectl -n "$KAFKA_NAMESPACE" wait "kafka/${KAFKA_CLUSTER}" --for=condition=Ready --timeout=600s >/dev/null
log "Done"
