#!/usr/bin/env bash
# Shared helpers. Source it from a prepare.sh / reset.sh:  . "$(dirname "$0")/../lib/common.sh"
set -euo pipefail

# Used by the scripts that source this file.
# shellcheck disable=SC2034
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# Fixed names of the labs. Versions are not kept here: every manifest and script names its versions literally.
KAFKA_NAMESPACE=kafka
KAFKA_CLUSTER=nordwind-kafka
export KAFKA_NAMESPACE KAFKA_CLUSTER

# Integration only (modules not yet reworked still use placeholders): versions.env and the render helpers.
# shellcheck disable=SC1091
. "$ROOT/versions.env"
VERSION_VARS="$(sed -n 's/^\([A-Z0-9_]*\)=.*/${\1}/p' "$ROOT/versions.env" | paste -sd' ' -)"
render() {
  set -a
  # shellcheck disable=SC1091
  . "$ROOT/versions.env"
  set +a
  envsubst "$VERSION_VARS" < "$1"
}
apply_tpl() { render "$1" | kubectl apply "${@:2}" -f -; }

# Tests from outside the VMs set NODE_SSH to a wrapper that reaches every node.
TEST_WRAPPER="${NODE_SSH:-}"
NODE_SSH="${NODE_SSH:-ssh}"

# Private prefix of the lab network, e.g. 10.3.238: node N is $IP.N. The platform gives every participant their own
# prefix; the image exports it in ~/.bashrc, read from the private interface like here.
if [ -z "${IP:-}" ]; then
  IP="$(ip -4 -o addr show dev enp7s0 2>/dev/null | awk '{split($4, a, "."); print a[1] "." a[2] "." a[3]; exit}')"
fi

# The scripts run on node1. `on node1 ...` then runs locally; node N is reached with `ssh $IP.N`. Both take the
# node and one command string. sudo needs no password on the lab VMs, so no terminal is required.
# The command string is assembled by the caller for execution on the selected node.
# shellcheck disable=SC2029
on() {
  if [ -n "$TEST_WRAPPER" ]; then $NODE_SSH "$1" "$2"
  elif [ "$1" = node1 ]; then bash -c "$2"
  else
    [ -n "$IP" ] || die "No private address on enp7s0: the prefix of the lab network (IP) is unknown."
    ssh "$IP.${1#node}" "$2"
  fi
}
export KUBECONFIG="${KUBECONFIG:-$HOME/.kube/config}"

log() { printf '\n\e[1m== %s\e[0m\n' "$*"; }
die() { printf '\e[31m%s\e[0m\n' "$*" >&2; exit 1; }

need() { command -v "$1" >/dev/null || die "$1 is missing."; }


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

# After a rebuild from cluster/kafka.yaml: cluster/nordwind-kafka.yaml has to describe the cluster that runs now, because
# the labs edit that file and apply it. A different file is kept as cluster/nordwind-kafka.yaml.bak.
adopt_reference_design() {
  local ref="$ROOT/cluster/kafka.yaml" mine="$ROOT/cluster/nordwind-kafka.yaml"
  [ -e "$ref" ] || return 0
  if [ -e "$mine" ] && ! cmp -s "$ref" "$mine"; then
    cp "$mine" "$mine.bak"
    log "cluster/nordwind-kafka.yaml now describes the rebuilt cluster (your file is saved as nordwind-kafka.yaml.bak)"
  fi
  cp "$ref" "$mine"
}

# The pod with the Kafka command line tools for the scripts that work from inside the cluster (tools/kafka-tools.yaml,
# applied by the participants in the design lab).
ensure_tools() {
  kubectl -n "$KAFKA_NAMESPACE" get deployment kafka-tools >/dev/null 2>&1 || "$ROOT/tools/prepare.sh" >/dev/null
}
