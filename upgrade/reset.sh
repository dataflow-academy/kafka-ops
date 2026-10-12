#!/usr/bin/env bash
# Rebuilds the cluster at the installed versions (see prepare.sh). Destroys all data. Run it on node1.
. "$(dirname "$0")/../lib/common.sh"
HERE="$(cd "$(dirname "$0")/.." && pwd)"
# Topics and users carry finalizers that only the Entity Operator removes: delete them while it still runs.
kubectl -n "$KAFKA_NAMESPACE" delete kafkatopic,kafkauser --all --ignore-not-found --timeout=180s >/dev/null 2>&1 || true
"$HERE/cluster/reset.sh"
"$HERE/cluster/prepare.sh"
"$HERE/monitoring/prepare.sh"
"$HERE/windpark/prepare.sh" healthy
