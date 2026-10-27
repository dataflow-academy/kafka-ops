#!/usr/bin/env bash
# Starts one failure on the Kafka cluster and does not say which broker it hit. Run it on node1.
#
#   ./break.sh P1     the operator scaled to 0, then a broker pod deleted (incident 1)
#   ./break.sh P1b    one more running broker pod deleted while the operator is still at 0 (second part of incident 1)
#   ./break.sh P4     the volume of a broker full, a "heap dump" fills it (incident 2)
#
# Participants who read this file spoil their own exercise; the symptoms are the
# exercise. heal.sh undoes every failure and checks the cluster afterwards.
. "$(dirname "$0")/lib.sh"
need kubectl; need jq
kube_ready || die "kubectl cannot reach the cluster."

pick="${1:?usage: break.sh P1|P1b|P4}"
touch "$HOME/.chaos-started"   # reset.sh removes it
brokers=(0 1 2)
broker="${brokers[$((RANDOM % 3))]}"

case "$pick" in
  P1) # operator gone, then a broker pod deleted: nobody recreates it
    operator_scale 0
    kubectl -n "$NS" delete pod "$(broker_pod "$broker")" --wait=false >/dev/null
    state_set P1 "broker-$broker" ;;
  P1b) # a second broker pod deleted; only while the operator is away, else it is back at once
    [ "$(kubectl -n "$NS" get deployment strimzi-cluster-operator -o jsonpath='{.spec.replicas}')" = 0 ] \
      || die "The operator runs: it would bring the broker back at once. Only while incident 1 is not repaired."
    running=$(kubectl -n "$NS" get pods -l strimzi.io/pool-name=broker --no-headers | awk '$3 == "Running" {print $1}')
    [ "$(wc -w <<<"$running")" -ge 2 ] || die "Fewer than two brokers run: nothing to do."
    victim=$(shuf -n1 <<<"$running")
    kubectl -n "$NS" delete pod "$victim" --wait=false >/dev/null
    state_set P1b "${victim#nordwind-kafka-}" ;;
  P4) # the volume of one broker is full (a loop file system of the size of its data, filled by a "heap dump")
    pod="$(broker_pod "$broker")"
    pvc="data-0-$pod"
    pv=$(kubectl -n "$NS" get pvc "$pvc" -o jsonpath='{.spec.volumeName}')
    dir=$(kubectl get pv "$pv" -o jsonpath='{.spec.hostPath.path}{.spec.local.path}')
    node=$(node_of_pod "$pod")
    step 1 "Preparing the incident"
    operator_scale 0
    kubectl -n "$NS" delete pod "$pod" --wait=false >/dev/null
    wait_for "pod stopped" 120 bash -c "! kubectl -n $NS get pod $pod"
    step 2 "Preparing the incident"
    on_node "$node" "set -e; D='$dir'; I=/var/lib/chaos-$pv.img; mkdir -p /mnt/chaos-tmp
      used=\$(du -sm \"\$D\" | cut -f1); truncate -s \$((used + 256))M \$I; mkfs.ext4 -q -F -m 0 \$I
      mount -o loop \$I /mnt/chaos-tmp; cp -a \"\$D/.\" /mnt/chaos-tmp/
      chown --reference=\"\$D\" /mnt/chaos-tmp; chmod --reference=\"\$D\" /mnt/chaos-tmp; umount /mnt/chaos-tmp
      mount -o loop \$I \"\$D\"" >/dev/null
    step 3 "Preparing the incident"
    on_node "$node" "D='$dir'; F=\"\$D/heap-dump-$(date +%Y%m%d).hprof\"
      fallocate -l \$(df -B1 --output=avail \"\$D\" | tail -1) \"\$F\" || true; chown --reference=\"\$D\" \"\$F\"" >/dev/null
    step 4 "Preparing the incident"
    operator_up_until_pod "$pod"
    state_set P4 "$pod" ;;
  *) die "Unknown failure $pick" ;;
esac
echo "Done. Something is wrong with the cluster now."
