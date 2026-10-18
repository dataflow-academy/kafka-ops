#!/usr/bin/env bash
# Installs k3s on node1 (server) and node2..3 (agents), pinned in versions.env,
# and puts a kubeconfig for `user` on node1. Run it on node1. Idempotent: nodes
# that already run the pinned version are left alone.
#
# The lab teaches the same steps by hand; this script is the catch-up path.
. "$(dirname "$0")/../lib/common.sh"

NODES="${NODES:-1 2 3}"
SUDO="${SUDO:-sudo}"

# Private address of node N: the address on the interface that carries the
# Hetzner private network route.
node_ip() {
  on "node$1" "dev=\$(ip -4 route show 10.0.0.0/8 | awk '{for(i=1;i<NF;i++) if(\$i==\"dev\"){print \$(i+1); exit}}'); \
    ip -4 -o addr show dev \"\$dev\" | awk '{sub(\"/.*\",\"\",\$4); print \$4; exit}'; echo \"\$dev\"" 
}

installed_version() { on "node$1" 'k3s --version 2>/dev/null | head -1' | awk '{print $3}'; }

read -r SERVER_IP IFACE < <(node_ip 1 | paste -sd' ')
log "k3s ${K3S_VERSION}: server node1 ($SERVER_IP, $IFACE)"

if [ "$(installed_version 1)" != "$K3S_VERSION" ]; then
  # Traefik and the service load balancer are not needed: everything is
  # reached through NodePorts, and the memory is better spent on Kafka.
  on node1 "curl -sfL https://get.k3s.io | $SUDO env INSTALL_K3S_VERSION='$K3S_VERSION' sh -s - server \
    --node-ip $SERVER_IP --advertise-address $SERVER_IP --flannel-iface $IFACE \
    --disable traefik --disable servicelb --write-kubeconfig-mode 644"
fi
wait_for "k3s server" 120 on node1 'kubectl --kubeconfig /etc/rancher/k3s/k3s.yaml get nodes'

TOKEN="$(on node1 "$SUDO cat /var/lib/rancher/k3s/server/node-token")"

for n in $NODES; do
  [ "$n" = 1 ] && continue
  read -r NODE_IP IFACE_N < <(node_ip "$n" | paste -sd' ')
  log "k3s agent node$n ($NODE_IP)"
  if [ "$(installed_version "$n")" != "$K3S_VERSION" ]; then
    on "node$n" "curl -sfL https://get.k3s.io | $SUDO env INSTALL_K3S_VERSION='$K3S_VERSION' \
      K3S_URL='https://$SERVER_IP:6443' K3S_TOKEN='$TOKEN' sh -s - agent \
      --node-ip $NODE_IP --flannel-iface $IFACE_N"
  fi
done

log "kubeconfig for user on node1"
on node1 'mkdir -p ~/.kube && cp /etc/rancher/k3s/k3s.yaml ~/.kube/config && chmod 600 ~/.kube/config'

log "waiting for all nodes to be Ready"
count=$(wc -w <<<"$NODES")
on node1 "for i in \$(seq 60); do [ \"\$(kubectl get nodes --no-headers 2>/dev/null | grep -c ' Ready')\" -ge $count ] && exit 0; sleep 3; done; exit 1" \
  || die "Not all nodes became Ready."
on node1 "kubectl get nodes -o wide"
