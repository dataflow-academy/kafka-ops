#!/usr/bin/env bash
# Removes k3s from all three nodes (agents first). Run it on node1.
. "$(dirname "$0")/../lib/common.sh"
SUDO="${SUDO:-sudo}"
[ -n "$TEST_WRAPPER" ] || $SUDO -v   # the password once, before the nodes
for n in 3 2; do
  log "node$n"
  on_sudo "node$n" "[ -x /usr/local/bin/k3s-agent-uninstall.sh ] && $SUDO /usr/local/bin/k3s-agent-uninstall.sh || true"
done
log "node1"
on_sudo node1 "[ -x /usr/local/bin/k3s-uninstall.sh ] && $SUDO /usr/local/bin/k3s-uninstall.sh || true"
on node1 'rm -rf ~/.kube'
