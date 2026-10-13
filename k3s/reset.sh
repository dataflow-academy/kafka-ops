#!/usr/bin/env bash
# Removes k3s from all three nodes (agents first). Run it on node1.
#
# The registry credential of the wind park images (/etc/rancher/k3s/registries.yaml, see the README) lives in the directory
# the k3s uninstall script deletes. Without it the next installation cannot pull the images, so it is kept aside and put back.
. "$(dirname "$0")/../lib/common.sh"
SUDO="${SUDO:-sudo}"
KEEP=/tmp/registries.yaml.keep
REG=/etc/rancher/k3s/registries.yaml
uninstall() {   # uninstall <node> <script>
  on "$1" "[ -f $REG ] && $SUDO cp -p $REG $KEEP; \
    [ -x $2 ] && $SUDO $2; \
    [ -f $KEEP ] && $SUDO mkdir -p /etc/rancher/k3s && $SUDO mv $KEEP $REG; true"
}
for n in 3 2; do
  log "node$n"
  uninstall "node$n" /usr/local/bin/k3s-agent-uninstall.sh
done
log "node1"
uninstall node1 /usr/local/bin/k3s-uninstall.sh
on node1 'rm -rf ~/.kube'
