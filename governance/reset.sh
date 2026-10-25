#!/usr/bin/env bash
# Removes the policies and the experiment resources of the governance lab and switches topic auto-creation back on
# (a rolling restart only if it was switched off). Idempotent.
. "$(dirname "$0")/../lib/common.sh"
kube_ready || die "kubectl cannot reach the cluster."
NS="$KAFKA_NAMESPACE"
kubectl delete validatingadmissionpolicybinding kafkatopic-naming kafkatopic-limits --ignore-not-found
kubectl delete validatingadmissionpolicy kafkatopic-naming kafkatopic-limits --ignore-not-found
kubectl -n "$NS" delete kafkatopic -l training/experiment=governance --ignore-not-found
# The grandfathering label is part of the lab: the existing topics lose it again. A policy that was just deleted needs a
# moment to stop rejecting the topics (they no longer follow the convention without the label), hence the retries.
for _ in $(seq 20); do
  kubectl -n "$NS" label kafkatopic --all governance.nordwind/grandfathered- >/dev/null 2>&1 && break
  sleep 3
done
rm -f "$HOME/.alerts-copied"
kubectl -n "$NS" exec deploy/kafka-tools -- kafka-configs.sh --bootstrap-server "my-cluster-kafka-bootstrap:9092" \
  --alter --entity-type clients --entity-name wartung --delete-config producer_byte_rate >/dev/null 2>&1 || true
current=$(kubectl -n "$NS" get kafka "$KAFKA_CLUSTER" -o "jsonpath={.spec.kafka.config.auto\.create\.topics\.enable}" 2>/dev/null || true)
if [ -n "$current" ]; then
  log "Removing the governance settings from the Kafka resource"
  kubectl -n "$NS" patch kafka "$KAFKA_CLUSTER" --type merge \
    -p '{"spec":{"kafka":{"config":{"auto.create.topics.enable":null,"num.partitions":null}}}}'
  kubectl -n "$NS" wait "kafka/$KAFKA_CLUSTER" --for=condition=Ready --timeout=900s
fi
