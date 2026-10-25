#!/usr/bin/env bash
# Undoes every failure that break.sh can cause (whichever is active, or none) and
# waits until the cluster is healthy again: Kafka Ready, all pods ready, all
# nodes Ready, no under-replicated partitions. Idempotent. Run it on node1.
. "$(dirname "$0")/lib.sh"
need kubectl; need jq
kube_ready || die "kubectl cannot reach the cluster."

# P2: node agents. A NotReady node needs its agent back; the helper pods that died with it must go.
for node in $(kubectl get nodes --no-headers | awk '$2 ~ /NotReady/ {print $1}'); do
  log "Starting k3s-agent on $node"
  host_sudo "$node" 'systemctl start k3s-agent' || log "could not start the agent on $node"
done
kubectl -n "$NS" delete pod -l app=chaos-helper --force --grace-period=0 >/dev/null 2>&1 || true
kubectl wait node --all --for=condition=Ready --timeout=180s >/dev/null

# P5: replication port. Remove the rules on every node (-D until none is left).
for node in $(kubectl get nodes -o name | sed 's|node/||'); do
  on_node "$node" "for dir in dport sport; do while iptables -t raw -D PREROUTING -p tcp --\$dir 9091 -j DROP 2>/dev/null; do :; done; done" >/dev/null
done

# P4: full volume. Put the data back on the real directory and drop the loop file system.
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

# P1, P3, P4, P6: operator back with its original namespace setting, topic operator too.
idx=$(kubectl -n "$NS" get deployment strimzi-cluster-operator -o json | jq '.spec.template.spec.containers[0].env | map(.name) | index("STRIMZI_NAMESPACE")')
kubectl -n "$NS" patch deployment strimzi-cluster-operator --type json -p "[{\"op\":\"replace\",\"path\":\"/spec/template/spec/containers/0/env/$idx\",\"value\":{\"name\":\"STRIMZI_NAMESPACE\",\"valueFrom\":{\"fieldRef\":{\"apiVersion\":\"v1\",\"fieldPath\":\"metadata.namespace\"}}}}]" >/dev/null
operator_up
kubectl -n "$NS" rollout status deployment/strimzi-cluster-operator --timeout=180s >/dev/null
kubectl -n "$NS" delete configmap chaos-state --ignore-not-found >/dev/null

log "Waiting for the cluster"
wait_for "Kafka Ready" 600 kubectl -n "$NS" wait "kafka/$KAFKA_CLUSTER" --for=condition=Ready --timeout=5s
kubectl -n "$NS" get deploy nordwind-kafka-entity-operator -o json | jq -e '.spec.template.spec.containers[]|select(.name=="topic-operator")|.env[]|select(.name=="STRIMZI_NAMESPACE" and .value=="default")' >/dev/null 2>&1 \
  && wait_for "topic operator back in $NS" 300 bash -c "! kubectl -n $NS get deploy nordwind-kafka-entity-operator -o json | jq -e '.spec.template.spec.containers[]|select(.name==\"topic-operator\")|.env[]|select(.name==\"STRIMZI_NAMESPACE\" and .value==\"default\")'"
wait_for "all pods ready" 600 bash -c "! kubectl -n $NS get pods -l strimzi.io/cluster=$KAFKA_CLUSTER --no-headers | grep -v ' 1/1\| 2/2'"
ensure_tools
wait_for "no under-replicated partitions" 300 bash -c "[ \"\$(kubectl -n $NS exec deploy/kafka-tools -- kafka-topics.sh --bootstrap-server $BOOTSTRAP --describe --under-replicated-partitions 2>/dev/null | grep -c Topic)\" = 0 ]"
log "Cluster healthy"
kubectl get nodes
