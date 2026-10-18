#!/usr/bin/env bash
# Print plain, editable manifests. This does not contact or change a cluster.
# Participants keep this output, edit it, and use kubectl apply -f themselves.
#   ./render.sh > ~/windpark.yaml
#   ./render.sh healthy > ~/windpark-healthy.yaml
. "$(dirname "$0")/../lib/common.sh"
need kubectl; need envsubst
: "${WIND_IMAGE_REGISTRY:?WIND_IMAGE_REGISTRY is not set. The lab VM provides it in /etc/kafka-ops.env.}"
HERE="$(cd "$(dirname "$0")" && pwd)"
case "${1:-training}" in
  training|as-requested) DIR="$HERE" ;;
  healthy) DIR="$HERE/base" ;;
  *) DIR="$HERE/$1" ;;
esac
# Finish Kustomize before printing anything: a failed render must not leave a partial manifest.
manifests="$(kubectl kustomize "$DIR")"
render /dev/stdin <<<"$manifests"
