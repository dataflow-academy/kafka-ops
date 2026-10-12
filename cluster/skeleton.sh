#!/usr/bin/env bash
# Writes the design skeleton of the cluster lab to ~/my-cluster.yaml with the pinned versions from
# versions.env filled in. Refuses to overwrite a file that is already there (your work!); remove it first
# or pass FORCE=1 to start over.
. "$(dirname "$0")/../lib/common.sh"
need envsubst
out="$HOME/my-cluster.yaml"
[ -z "${FORCE:-}" ] && [ -e "$out" ] && die "$out exists. Move it away or run FORCE=1 $0 to start over."
render "$(dirname "$0")/skeleton.yaml" > "$out"
echo "Wrote $out"
