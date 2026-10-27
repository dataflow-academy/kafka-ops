#!/usr/bin/env bash
# Removes what the multi-cluster lab creates in your cluster: the mirror, the topics it wrote (internal ones and the
# mirrored <region>.<topic>), the Secret with the neighbor's CA certificate. The working files go back to their
# frames. The listener externaltls stays (it is part of cluster/nordwind-kafka.yaml). Run it on node1. Idempotent.
. "$(dirname "$0")/../lib/common.sh"
need kubectl
kube_ready || { echo "No cluster reachable, nothing to reset."; exit 0; }
N=(-n "$KAFKA_NAMESPACE")
kubectl "${N[@]}" get kafka "$KAFKA_CLUSTER" >/dev/null 2>&1 || { echo "No Kafka cluster, nothing to reset."; exit 0; }
HERE="$(cd "$(dirname "$0")" && pwd)"

aliases=""
if kubectl "${N[@]}" get kafkamirrormaker2 mm2 >/dev/null 2>&1; then
  aliases="$(kubectl "${N[@]}" get kafkamirrormaker2 mm2 -o jsonpath='{.spec.mirrors[*].source.alias}')"
  log "Deleting the mirror"
  kubectl "${N[@]}" delete kafkamirrormaker2 mm2 --timeout=180s >/dev/null
  kubectl "${N[@]}" wait pod -l strimzi.io/cluster=mm2 --for=delete --timeout=180s >/dev/null 2>&1 || true
fi
kubectl "${N[@]}" delete secret neighbor-cluster-ca --ignore-not-found >/dev/null

# Internal topics of MirrorMaker 2, and the mirrored topics: the source alias in front (never the own prefix nordwind).
pattern='mm2-configs|mm2-offsets|mm2-status|mm2-offset-syncs\..*\.internal|.*\.checkpoints\.internal|heartbeats'
for a in $aliases; do
  [ "$a" = nordwind ] || pattern="$pattern|${a}\\..*"
done
ensure_tools
kubectl "${N[@]}" rollout status deployment/kafka-tools --timeout=180s >/dev/null
tools=(kubectl "${N[@]}" exec deploy/kafka-tools -- kafka-topics.sh --bootstrap-server "${KAFKA_CLUSTER}-kafka-bootstrap:9092")
topics="$("${tools[@]}" --list | grep -E "^(${pattern})\$" || true)"
for t in $topics; do
  log "Deleting topic $t"
  "${tools[@]}" --delete --topic "$t" >/dev/null
done

cp "$HERE/mirrormaker2-frame.yaml" "$HERE/mirrormaker2.yaml"
: > "$HERE/neighbor-ca.crt"
