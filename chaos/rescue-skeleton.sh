#!/usr/bin/env bash
# Prepare a plain YAML manifest for inspecting a broker volume; change claimName before applying it.
. "$(dirname "$0")/../lib/common.sh"
need envsubst
render "$ROOT/chaos/rescue-pod.yaml" > "$HOME/rescue.yaml"
echo "Edit ~/rescue.yaml, then apply it with kubectl apply -f ~/rescue.yaml."
