#!/usr/bin/env bash
# Undoes every failure that break.sh and the lab can cause (whichever is active, or none) and
# waits until the cluster is healthy again: Kafka Ready, all pods ready, all
# nodes Ready, no under-replicated partitions. Idempotent. Run it on node1.
. "$(dirname "$0")/lib.sh"
need kubectl; need jq
kube_ready || die "kubectl cannot reach the cluster."

# A node whose agent was stopped (the node failure of the lab) needs its agent back; helper pods that died with it must go.
for node in $(kubectl get nodes --no-headers | awk '$2 ~ /NotReady/ {print $1}'); do
  log "Starting k3s-agent on $node"
  host_sudo "$node" 'systemctl start k3s-agent' || log "could not start the agent on $node"
done
kubectl -n "$NS" delete pod -l app=chaos-helper --force --grace-period=0 >/dev/null 2>&1 || true
kubectl wait node --all --for=condition=Ready --timeout=180s >/dev/null
kubectl -n "$NS" delete pod rescue --ignore-not-found --wait=true >/dev/null

# P4: full volume. A rescue pod of the participants would keep the volume busy. Put the data back on the real directory and drop the loop file system.
for pv in $(kubectl get pv -o name | sed 's|persistentvolume/||'); do
  dir=$(kubectl get pv "$pv" -o jsonpath='{.spec.hostPath.path}{.spec.local.path}')
  claim=$(kubectl get pv "$pv" -o jsonpath='{.spec.claimRef.name}')
  [[ "$claim" == data-0-nordwind-kafka-broker-* ]] || continue
  pod="${claim#data-0-}"
  # which node holds the directory: the node affinity of the volume, else where the pod ran
  node=$(kubectl get pv "$pv" -o jsonpath='{.spec.nodeAffinity.required.nodeSelectorTerms[0].matchExpressions[0].values[0]}')
  img="/var/lib/chaos-$pv.img"
  out=$(on_node "$node" "test -f $img && mount | grep -q ' on $dir ' && echo loop" || true)
  if grep -q loop <<<"$out"; then
    log "Freeing the volume of $pod"
    operator_scale 0
    kubectl -n "$NS" delete pod "$pod" --wait=true >/dev/null 2>&1 || true
    on_node "$node" "set -e; mkdir -p /mnt/chaos-tmp; mount -o loop $img /mnt/chaos-tmp; umount '$dir'
      rm -f /mnt/chaos-tmp/heap-dump-*.hprof; cp -a /mnt/chaos-tmp/. '$dir'/; umount /mnt/chaos-tmp; rm -f $img" >/dev/null
  fi
done

# P1, P1b, P4 and the hand-made failures of the lab (operator at 0, pods deleted): operator back.
operator_up
kubectl -n "$NS" rollout status deployment/strimzi-cluster-operator --timeout=180s >/dev/null
kubectl -n "$NS" delete configmap chaos-state --ignore-not-found >/dev/null

log "Waiting for the cluster"
wait_for "Kafka Ready" 600 kubectl -n "$NS" wait "kafka/$KAFKA_CLUSTER" --for=condition=Ready --timeout=5s
wait_for "all pods ready" 600 bash -c "! kubectl -n $NS get pods -l strimzi.io/cluster=$KAFKA_CLUSTER --no-headers | grep -v ' 1/1\| 2/2'"
ensure_tools
wait_for "no under-replicated partitions" 300 bash -c "[ \"\$(kubectl -n $NS exec deploy/kafka-tools -- kafka-topics.sh --bootstrap-server $BOOTSTRAP --describe --under-replicated-partitions 2>/dev/null | grep -c Topic)\" = 0 ]"
log "Cluster healthy"
kubectl get nodes
