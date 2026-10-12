#!/usr/bin/env bash
# Applies the wind park: renders the manifests (the registry of the images and the versions come from
# /etc/kafka-ops.env and versions.env, they are not part of the public repository) and applies them.
# The topics of the onboarding requests are not touched: participants create them themselves.
#
#   ./apply.sh               the faulty wind park as participants meet it (faults F1-F5)
#   ./apply.sh healthy       no faults
#   ./apply.sh <dir>         any kustomization below windpark/ (for example fixes/<name>)
. "$(dirname "$0")/../lib/common.sh"
need kubectl; need envsubst
kube_ready || die "kubectl cannot reach the cluster."
: "${WIND_IMAGE_REGISTRY:?WIND_IMAGE_REGISTRY is not set. The lab VM provides it in /etc/kafka-ops.env.}"
HERE="$(cd "$(dirname "$0")" && pwd)"
MODE="${1:-training}"
case "$MODE" in
  training|as-requested) DIR="$HERE" ;;
  healthy) DIR="$HERE/base" ;;
  *) DIR="$HERE/$MODE" ;;
esac

log "Wind park (${MODE})"
manifests="$(kubectl kustomize "$DIR" | render /dev/stdin)"
# The applications and their ConfigMaps live in `windpark`, the team-owned KafkaTopics in `kafka`.
# Prune removes what a fix took out of the kustomization.
split_docs() { python3 -c '
import sys
want_topic = sys.argv[1] == "topic"
docs = [d for d in sys.stdin.read().split("\n---\n") if d.strip()]
print("\n---\n".join(d for d in docs if ("kind: KafkaTopic" in d) == want_topic))' "$1"; }
split_docs apps <<<"$manifests" | kubectl apply -n windpark --prune -l app.kubernetes.io/part-of=wind-park \
  --prune-allowlist=core/v1/ConfigMap --prune-allowlist=apps/v1/Deployment --prune-allowlist=batch/v1/CronJob -f -
split_docs topic <<<"$manifests" | kubectl apply -n "$KAFKA_NAMESPACE" --prune -l app.kubernetes.io/part-of=wind-park \
  --prune-allowlist=kafka.strimzi.io/v1/KafkaTopic -f -

echo "Applied. The pods start in the namespace windpark: kubectl -n windpark get pods"
