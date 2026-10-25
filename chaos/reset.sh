#!/usr/bin/env bash
# Undoes every failure and removes the experiment topics. Idempotent.
. "$(dirname "$0")/lib.sh"
kube_ready || die "kubectl cannot reach the cluster."
"$(dirname "$0")/heal.sh"
kubectl -n "$NS" delete kafkatopic -l training/experiment=failures --ignore-not-found
rm -f "$HOME/.chaos-started" "$HOME"/.bad-things{1,1b,2}-started
