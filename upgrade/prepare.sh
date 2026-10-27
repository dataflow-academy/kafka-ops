#!/usr/bin/env bash
# Start state for the upgrade lab: the cluster runs the installed versions (Strimzi 1.1.0, Kafka 4.2.1, metadata
# version 4.2-IV1), is Ready, and the monitoring and the wind park run on it. A cluster that was upgraded
# cannot be taken back (Strimzi does not roll a raised metadata version back), so a changed cluster is rebuilt
# from scratch: cluster/reset.sh, cluster/prepare.sh, then monitoring and the wind park. Run it on node1.
. "$(dirname "$0")/../lib/common.sh"
need kubectl
kube_ready || die "kubectl cannot reach the cluster."
N=(-n "$KAFKA_NAMESPACE")
HERE="$(cd "$(dirname "$0")/.." && pwd)"

state="$(kubectl "${N[@]}" get kafka "$KAFKA_CLUSTER" -o jsonpath='{.status.kafkaVersion}/{.status.kafkaMetadataVersion}/{.status.operatorLastSuccessfulVersion}' 2>/dev/null || true)"
op="$(kubectl "${N[@]}" get deployment strimzi-cluster-operator -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null || true)"
want="4.2.1/4.2-IV1/1.1.0"
if [ "$state" != "$want" ] || [ "${op##*:}" != "1.1.0" ]; then
  log "Cluster is not at the installed versions (is: ${state:-none}, operator ${op##*:}); rebuilding"
  # Topics and users carry finalizers that only the Entity Operator removes: delete them while it still runs.
  kubectl -n "$KAFKA_NAMESPACE" delete kafkatopic,kafkauser --all --ignore-not-found --timeout=180s >/dev/null 2>&1 || true
  "$HERE/cluster/reset.sh"
  "$HERE/cluster/prepare.sh"
  # The labs edit cluster/nordwind-kafka.yaml: after the rebuild it has to be the file of the cluster that runs now.
  adopt_reference_design
  "$HERE/monitoring/prepare.sh"
  "$HERE/windpark/prepare.sh" healthy
elif [ -n "$(kubectl "${N[@]}" get kafka "$KAFKA_CLUSTER" -o jsonpath='{.spec.kafka.authorization.type}')" ]; then
  # Right versions, authorization from the security lab: users and ACLs go, the wind park returns to the plain listener.
  log "Authorization is on (security lab): users and ACLs go, everyone may connect again"
  "$HERE/security/reset.sh" --keep-authorization
fi
kubectl "${N[@]}" wait "kafka/${KAFKA_CLUSTER}" --for=condition=Ready --timeout=600s
kubectl -n windpark get deployment control-room >/dev/null 2>&1 || "$HERE/windpark/prepare.sh" healthy
log "Done"
kubectl "${N[@]}" get kafka "$KAFKA_CLUSTER" -o jsonpath='{.status.kafkaVersion} {.status.kafkaMetadataVersion} {.status.operatorLastSuccessfulVersion}{"\n"}'
