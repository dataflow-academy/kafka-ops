#!/usr/bin/env bash
# Start state "wind park running": the applications of the six teams in the namespace `windpark`,
# with the faults F1-F5 built in (see README). Needs the cluster (cluster/prepare.sh). Run it on node1.
# Idempotent.
#
#   ./prepare.sh                 faulty wind park; the topics of the onboarding requests are created
#                                as a careful platform team would (only if they do not exist yet)
#   ./prepare.sh as-requested    same, but the topics approved as requested (fault F6)
#   ./prepare.sh healthy         no faults
#   ./prepare.sh <dir>           any kustomization below windpark/ (for example fixes/<name>)
#
# The images come from the registry named in /etc/kafka-ops.env. For tests without access,
# STAGE_IMAGES_FROM=<dir with the application sources> builds them on this node and imports them
# into k3s on all nodes.
. "$(dirname "$0")/../lib/common.sh"
need kubectl; need envsubst
kube_ready || die "kubectl cannot reach the cluster."
kubectl -n "$KAFKA_NAMESPACE" get kafka "$KAFKA_CLUSTER" >/dev/null 2>&1 || die "Kafka cluster is missing. Run cluster/prepare.sh first."
: "${WIND_IMAGE_REGISTRY:?WIND_IMAGE_REGISTRY is not set. The lab VM provides it in /etc/kafka-ops.env.}"
HERE="$(cd "$(dirname "$0")" && pwd)"
MODE="${1:-training}"
SUDO="${SUDO:-sudo}"
NODES="${NODES:-1 2 3}"
TOPIC_VARIANT=sensible
case "$MODE" in
  training) DIR="$HERE" ;;
  as-requested) DIR="$HERE"; TOPIC_VARIANT=as-requested ;;
  healthy) DIR="$HERE/base" ;;
  *) DIR="$HERE/$MODE" ;;
esac

if [ -n "${STAGE_IMAGES_FROM:-}" ]; then
  need docker
  for spec in java/wind-turbine-producer-json:java/producer-json java/wind-turbine-consumer-json:java/consumer-json \
              python/wind-masterdata-producer:python/masterdata-producer; do
    image="${WIND_IMAGE_REGISTRY}/${spec%%:*}:${WIND_IMAGE_TAG}"
    log "Test stopgap: building $image"
    docker image inspect "$image" >/dev/null 2>&1 || docker build -q -t "$image" "$STAGE_IMAGES_FROM/${spec##*:}" >/dev/null
    for n in $NODES; do
      docker save "$image" | $NODE_SSH "node$n" "$SUDO k3s ctr images import -" >/dev/null
    done
  done
fi

log "Topics of the onboarding requests (${TOPIC_VARIANT})"
# Only topics that do not exist yet: never overwrite what a group has created.
for f in "$HERE/topics/$TOPIC_VARIANT"/{telemetry,turbine-registry,park-registry}.yaml; do
  name="$(sed -n 's/^  name: //p' "$f")"
  if kubectl -n "$KAFKA_NAMESPACE" get kafkatopic "$name" >/dev/null 2>&1; then echo "exists: $name"; else kubectl apply -f "$f"; fi
done

"$HERE/apply.sh" "$MODE"
for d in scada-telemetry assets-stammdaten leitwarte prognose abrechnung alarme; do
  kubectl -n windpark rollout status "deployment/$d" --timeout=240s || true
done
kubectl -n windpark get pods
