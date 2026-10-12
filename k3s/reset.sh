#!/usr/bin/env bash
# Removes k3s from all three nodes (agents first). Run it on node1.
. "$(dirname "$0")/../lib/common.sh"
SUDO="${SUDO:-sudo}"
for n in 3 2; do
  log "node$n"
  $NODE_SSH "node$n" "[ -x /usr/local/bin/k3s-agent-uninstall.sh ] && $SUDO /usr/local/bin/k3s-agent-uninstall.sh || true"
done
log "node1"
$NODE_SSH node1 "[ -x /usr/local/bin/k3s-uninstall.sh ] && $SUDO /usr/local/bin/k3s-uninstall.sh || true"
$NODE_SSH node1 'rm -rf ~/.kube'
