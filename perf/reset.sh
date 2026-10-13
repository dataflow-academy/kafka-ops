#!/usr/bin/env bash
# Removes all perf topics and Jobs. Run it on node1. Idempotent.
. "$(dirname "$0")/../lib/common.sh"
need kubectl
kube_ready || { echo "No cluster reachable, nothing to reset."; exit 0; }
kubectl -n "$KAFKA_NAMESPACE" delete job,kafkatopic -l app.kubernetes.io/part-of=perf --ignore-not-found
