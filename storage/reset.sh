#!/usr/bin/env bash
# Removes the experiment topics and undoes the tuning of the master data topic. Idempotent.
. "$(dirname "$0")/../lib/common.sh"
kube_ready || die "kubectl cannot reach the cluster."
NS="$KAFKA_NAMESPACE"
kubectl -n "$NS" delete kafkatopic -l training/experiment=storage --ignore-not-found
reg=nordwind.assets.public.turbine-registry.state
if kubectl -n "$NS" get kafkatopic "$reg" >/dev/null 2>&1; then
  kubectl -n "$NS" patch kafkatopic "$reg" --type merge \
    -p '{"spec":{"config":{"segment.ms":null,"min.cleanable.dirty.ratio":null,"delete.retention.ms":null,"max.compaction.lag.ms":null}}}' >/dev/null
fi
