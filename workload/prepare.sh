#!/usr/bin/env bash
# Start state "workload running": topic, wind park producer and consumers.
# Needs the cluster (cluster/prepare.sh). Run it on node1. Idempotent.
#
#   ./prepare.sh [overlay]     overlay = training (default, with the faults) | healthy | after-<lab> | your own
#
# The images come from the registry configured in versions.env, pinned by commit
# SHA in versions.env. The nodes need pull credentials (k3s registries.yaml);
# without them the pods stay in ImagePullBackOff. For tests without access,
# STAGE_IMAGES_FROM=<dir with the application sources> builds the same images on this
# node and imports them into k3s on all nodes under the pinned names.
. "$(dirname "$0")/../lib/common.sh"
need kubectl; need envsubst
kube_ready || die "kubectl cannot reach the cluster."
kubectl -n "$KAFKA_NAMESPACE" get kafka "$KAFKA_CLUSTER" >/dev/null 2>&1 || die "Kafka cluster is missing. Run cluster/prepare.sh first."

: "${WIND_IMAGE_REGISTRY:?WIND_IMAGE_REGISTRY is not set. The lab VM provides it in /etc/kafka-ops.env.}"
HERE="$(cd "$(dirname "$0")" && pwd)"
OVERLAY="${1:-training}"
SUDO="${SUDO:-sudo}"
NODES="${NODES:-1 2 3}"

if [ -n "${STAGE_IMAGES_FROM:-}" ]; then
  need docker
  for app in producer consumer; do
    image="${WIND_IMAGE_REGISTRY}/java/wind-turbine-${app}-json:${WIND_IMAGE_TAG}"
    log "Test stopgap: building $image"
    docker build -q -t "$image" "$STAGE_IMAGES_FROM/java/${app}-json" >/dev/null
    for n in $NODES; do
      docker save "$image" | $NODE_SSH "node$n" "$SUDO k3s ctr images import -" >/dev/null
    done
  done
fi

log "Workload (${OVERLAY})"
kubectl kustomize "$HERE/overlays/$OVERLAY" | render /dev/stdin | kubectl -n "$KAFKA_NAMESPACE" apply --prune -l app.kubernetes.io/part-of=wind-park \
  --prune-allowlist=core/v1/ConfigMap --prune-allowlist=apps/v1/Deployment -f -
kubectl -n "$KAFKA_NAMESPACE" wait kafkatopic/nordwind.scada.public.turbine-telemetry-json.event --for=condition=Ready --timeout=120s
kubectl -n "$KAFKA_NAMESPACE" get pods -l app.kubernetes.io/part-of=wind-park
