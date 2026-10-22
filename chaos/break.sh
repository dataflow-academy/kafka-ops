#!/usr/bin/env bash
# Starts one failure on the Kafka cluster. Without an argument it picks one of
# P4..P6 at random and does not say which (P1..P3 repeat what the lab has just done by hand;
# name them as the argument if you want them). Run it on node1.
#
#   ./break.sh [P1|P2|P3|P4|P5|P6]
#
# Participants who read this file spoil their own exercise; the symptoms are the
# exercise. heal.sh undoes every failure and checks the cluster afterwards.
. "$(dirname "$0")/lib.sh"
need kubectl; need jq
kube_ready || die "kubectl cannot reach the cluster."

pick="${1:-P$((RANDOM % 3 + 4))}"
touch "$HOME/.chaos-started"   # the lab self-check looks for this file; reset.sh removes it
brokers=(0 1 2)
broker="${brokers[$((RANDOM % 3))]}"
agents=$(kubectl get nodes -l '!node-role.kubernetes.io/control-plane' -o name | sed 's|node/||')
agent=$(shuf -n1 <<<"$agents")

case "$pick" in
  P1) # operator gone, then a broker pod deleted: nobody recreates it
    operator_scale 0
    kubectl -n "$NS" delete pod "$(broker_pod "$broker")" --wait=false >/dev/null
    state_set P1 "broker-$broker" ;;
  P2) # a node loses its k3s agent: containers stop, the node turns NotReady
    on_node "$agent" 'systemd-run --no-block --quiet /usr/local/bin/k3s-killall.sh' >/dev/null || true
    state_set P2 "$agent" ;;
  P3) # two of three controllers gone, the operator cannot bring them back
    operator_scale 0
    kubectl -n "$NS" delete pod my-cluster-controller-100 my-cluster-controller-101 --wait=false >/dev/null
    state_set P3 "controllers-100-101" ;;
  P4) # the volume of one broker is full (a loop file system of the size of its data, filled by a "heap dump")
    pod="$(broker_pod "$broker")"
    pvc="data-0-$pod"
    pv=$(kubectl -n "$NS" get pvc "$pvc" -o jsonpath='{.spec.volumeName}')
    dir=$(kubectl get pv "$pv" -o jsonpath='{.spec.hostPath.path}{.spec.local.path}')
    node=$(node_of_pod "$pod")
    operator_scale 0
    kubectl -n "$NS" delete pod "$pod" --wait=true >/dev/null
    on_node "$node" "set -e; D='$dir'; I=/var/lib/chaos-$pv.img; mkdir -p /mnt/chaos-tmp
      used=\$(du -sm \"\$D\" | cut -f1); truncate -s \$((used + 256))M \$I; mkfs.ext4 -q -F -m 0 \$I
      mount -o loop \$I /mnt/chaos-tmp; cp -a \"\$D/.\" /mnt/chaos-tmp/
      chown --reference=\"\$D\" /mnt/chaos-tmp; chmod --reference=\"\$D\" /mnt/chaos-tmp; umount /mnt/chaos-tmp
      mount -o loop \$I \"\$D\"
      fallocate -l \$(df -B1 --output=avail \"\$D\" | tail -1) \"\$D/heap-dump-$(date +%Y%m%d).hprof\" || true
      chown --reference=\"\$D\" \"\$D/heap-dump-$(date +%Y%m%d).hprof\"" >/dev/null
    operator_up
    state_set P4 "$pod" ;;
  P5) # node cannot replicate: the replication port is dropped in both directions
    on_node "$agent" 'iptables -t raw -I PREROUTING 1 -p tcp --dport 9091 -j DROP; iptables -t raw -I PREROUTING 1 -p tcp --sport 9091 -j DROP' >/dev/null
    state_set P5 "$agent" ;;
  P6) # the operator watches another namespace and leaves the topic operator in the wrong one
    kubectl -n "$NS" set env deployment/my-cluster-entity-operator -c topic-operator STRIMZI_NAMESPACE=default >/dev/null
    kubectl -n "$NS" set env deployment/strimzi-cluster-operator STRIMZI_NAMESPACE=default >/dev/null
    state_set P6 "operator" ;;
  *) die "Unknown failure $pick" ;;
esac
echo "Done. Something is wrong with the cluster now."
