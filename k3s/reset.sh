#!/usr/bin/env bash
# Removes k3s from all three nodes (agents first). Run it on node1.
. "$(dirname "$0")/../lib/common.sh"
SUDO="${SUDO:-sudo}"
uninstall() {   # uninstall <node> <script>
  on "$1" "[ -x $2 ] && $SUDO $2; true"
}
for n in 3 2; do
  log "node$n"
  uninstall "node$n" /usr/local/bin/k3s-agent-uninstall.sh
done
log "node1"
uninstall node1 /usr/local/bin/k3s-uninstall.sh
on node1 'rm -rf ~/.kube'
