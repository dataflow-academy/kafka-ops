#!/usr/bin/env bash
# Removes the small cluster `hello` (k3s and the operator stay). Run it on node1. Idempotent.
. "$(dirname "$0")/../lib/common.sh"
need kubectl
kube_ready || { echo "No cluster reachable, nothing to reset."; exit 0; }
kubectl -n "$KAFKA_NAMESPACE" delete kafkatopic hello --ignore-not-found --wait=true --timeout=60s || true
kubectl -n "$KAFKA_NAMESPACE" delete kafka hello --ignore-not-found --wait=true --timeout=180s
kubectl -n "$KAFKA_NAMESPACE" delete kafkanodepool single --ignore-not-found
