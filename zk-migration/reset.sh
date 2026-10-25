#!/usr/bin/env bash
# Back to the modern stack of the other labs: removes the old Strimzi, the ZooKeeper cluster and the load, then
# installs Strimzi, the cluster, the monitoring and the wind park again. Destroys all data. Run it on node1.
. "$(dirname "$0")/../lib/common.sh"
need kubectl
HERE="$(cd "$(dirname "$0")/.." && pwd)"
if kubectl -n "$KAFKA_NAMESPACE" get deployment strimzi-cluster-operator >/dev/null 2>&1; then
  kubectl -n "$KAFKA_NAMESPACE" delete kafkatopic,kafkauser --all --ignore-not-found --timeout=180s >/dev/null 2>&1 || true
  "$HERE/cluster/reset.sh"
fi
"$HERE/cluster/prepare.sh"
adopt_reference_design
"$HERE/monitoring/prepare.sh"
"$HERE/windpark/prepare.sh" healthy
