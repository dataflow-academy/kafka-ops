#!/usr/bin/env bash
# Rescue path of the first lab, the same steps as the lab text: the latest k3s release with its defaults, the
# server on node1, agents on node2 and node3, the kubeconfig copied to ~/.kube/config with the namespace kafka as
# the default. Run it on node1. Idempotent: a node that runs k3s already is left alone.
. "$(dirname "$0")/../lib/common.sh"

NODES="${NODES:-1 2 3}"
SUDO="${SUDO:-sudo}"
[ -n "$IP" ] || die "No private address on enp7s0: the prefix of the lab network (IP) is unknown."
# Expanded on the node: the kubectl of k3s reads ~/.kube/config only when KUBECONFIG names it.
# shellcheck disable=SC2016
KC='KUBECONFIG=$HOME/.kube/config'

has_k3s() { on "node$1" 'command -v k3s >/dev/null'; }

log "k3s server on node1"
has_k3s 1 || on node1 "curl -sfL https://get.k3s.io | sh -"
wait_for "k3s kubeconfig" 120 on node1 "$SUDO test -s /etc/rancher/k3s/k3s.yaml"

log "kubeconfig for user, namespace kafka"
on node1 "mkdir -p ~/.kube && $SUDO cat /etc/rancher/k3s/k3s.yaml > ~/.kube/config && chmod 600 ~/.kube/config"
on node1 "$KC kubectl config set-context --current --namespace $KAFKA_NAMESPACE >/dev/null"
wait_for "k3s server" 120 on node1 "$KC kubectl get nodes"

TOKEN="$(on node1 "$SUDO cat /var/lib/rancher/k3s/server/node-token")"
for n in $NODES; do
  [ "$n" = 1 ] && continue
  log "k3s agent node$n"
  has_k3s "$n" || on "node$n" "curl -sfL https://get.k3s.io | K3S_URL=https://$IP.1:6443 K3S_TOKEN='$TOKEN' sh -"
done

log "waiting for all nodes to be Ready"
count=$(wc -w <<<"$NODES")
on node1 "for i in \$(seq 60); do [ \"\$($KC kubectl get nodes --no-headers 2>/dev/null | grep -c ' Ready')\" -ge $count ] && exit 0; sleep 3; done; exit 1" \
  || die "Not all nodes became Ready."
on node1 "$KC kubectl get nodes -o wide"
