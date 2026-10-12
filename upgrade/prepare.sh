#!/usr/bin/env bash
# Start state for the upgrade lab: the cluster runs the installed versions from versions.env (Strimzi, Kafka
# and metadata version), is Ready, and the monitoring and the wind park run on it. A cluster that was upgraded
# cannot be taken back (Kafka does not downgrade across the metadata version), so a changed cluster is rebuilt
# from scratch: cluster/reset.sh, cluster/prepare.sh, then monitoring and the wind park. Run it on node1.
. "$(dirname "$0")/../lib/common.sh"
need kubectl
kube_ready || die "kubectl cannot reach the cluster."
N=(-n "$KAFKA_NAMESPACE")
HERE="$(cd "$(dirname "$0")/.." && pwd)"

state="$(kubectl "${N[@]}" get kafka "$KAFKA_CLUSTER" -o jsonpath='{.status.kafkaVersion}/{.status.kafkaMetadataVersion}/{.status.operatorLastSuccessfulVersion}' 2>/dev/null || true)"
op="$(kubectl "${N[@]}" get deployment strimzi-cluster-operator -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null || true)"
want="${KAFKA_VERSION}/${KAFKA_METADATA_VERSION}/${STRIMZI_VERSION}"
if [ "$state" != "$want" ] || [ "${op##*:}" != "$STRIMZI_VERSION" ]; then
  log "Cluster is not at the installed versions (is: ${state:-none}, operator ${op##*:}); rebuilding"
  # Topics and users carry finalizers that only the Entity Operator removes: delete them while it still runs.
  kubectl -n "$KAFKA_NAMESPACE" delete kafkatopic,kafkauser --all --ignore-not-found --timeout=180s >/dev/null 2>&1 || true
  "$HERE/cluster/reset.sh"
  "$HERE/cluster/prepare.sh"
  "$HERE/monitoring/prepare.sh"
  "$HERE/windpark/prepare.sh" healthy
fi
kubectl "${N[@]}" wait "kafka/${KAFKA_CLUSTER}" --for=condition=Ready --timeout=600s
kubectl -n windpark get deployment leitwarte >/dev/null 2>&1 || "$HERE/windpark/prepare.sh" healthy
log "Done"
kubectl "${N[@]}" get kafka "$KAFKA_CLUSTER" -o jsonpath='{.status.kafkaVersion} {.status.kafkaMetadataVersion} {.status.operatorLastSuccessfulVersion}{"\n"}'
