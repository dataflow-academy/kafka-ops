#!/usr/bin/env bash
# Shared helpers. Source it from a prepare.sh / reset.sh:  . "$(dirname "$0")/../lib/common.sh"
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck disable=SC1091
. "$ROOT/versions.env"
# Provided by the lab VM: where the workload images live (see versions.env).
# shellcheck disable=SC1091
[ -r /etc/kafka-ops.env ] && . /etc/kafka-ops.env
export KAFKA_NAMESPACE KAFKA_CLUSTER

# Lab VMs are reached with `ssh node1..3`. Tests override NODE_SSH.
NODE_SSH="${NODE_SSH:-ssh}"
export KUBECONFIG="${KUBECONFIG:-$HOME/.kube/config}"

log() { printf '\n\e[1m== %s\e[0m\n' "$*"; }
die() { printf '\e[31m%s\e[0m\n' "$*" >&2; exit 1; }

need() { command -v "$1" >/dev/null || die "$1 is missing."; }

# Replaces ${VAR} placeholders with the values from versions.env and nothing
# else, so a literal $1 in a manifest (Prometheus relabeling) survives.
VERSION_VARS="$(sed -n 's/^\([A-Z0-9_]*\)=.*/${\1}/p' "$ROOT/versions.env" | paste -sd' ' -) \${WIND_IMAGE_REGISTRY}"
render() {
  set -a
  # shellcheck source=../versions.env
  . "$ROOT/versions.env"
  # The optional VM-local registry settings are not part of the repository.
  # shellcheck source=/dev/null
  [ -r /etc/kafka-ops.env ] && . /etc/kafka-ops.env
  set +a
  envsubst "$VERSION_VARS" < "$1"
}
apply_tpl() { render "$1" | kubectl apply "${@:2}" -f -; }

# Polls until a command succeeds. wait_for "what" seconds cmd...
wait_for() {
  local what="$1" limit="$2"; shift 2
  local start=$SECONDS
  until "$@" >/dev/null 2>&1; do
    [ $((SECONDS - start)) -lt "$limit" ] || die "Timed out after ${limit}s waiting for: $what"
    sleep 3
  done
}

kube_ready() { kubectl version >/dev/null 2>&1; }
