#!/usr/bin/env bash
# Makes sure every node can pull from the in-cluster registry. The registry is addressed by its service name
# (registry.registry.svc:5000), which resolves only inside Pods; the kubelet pulls on the node, so containerd
# needs a mirror for that name that points at the NodePort of the registry on the node itself
# (/etc/rancher/k3s/registries.yaml). The lab VMs have this entry already. The script tries a real pull on each
# node and adds the entry only where the pull fails, keeping every other entry.
# Run it on node1 after registry.yaml is applied. Idempotent.
. "$(dirname "$0")/../lib/common.sh"
need docker
SUDO="${SUDO:-sudo}"
CONF=/etc/rancher/k3s/registries.yaml
HOST=registry.registry.svc:5000
PROBE_SRC=public.ecr.aws/docker/library/busybox:1.37

ssh_t() { if [ "$NODE_SSH" = ssh ]; then ssh -t "$@"; else $NODE_SSH "$@"; fi; }

# Prints the names of the nodes that cannot pull $HOST/probe:1.
failing_nodes() {
  local node bad=()
  for node in $(kubectl get nodes -o name | cut -d/ -f2); do
    kubectl delete pod "probe-$node" --ignore-not-found --now >/dev/null
    kubectl run "probe-$node" --image="$HOST/probe:1" --image-pull-policy=Always --restart=Never --overrides="{\"spec\":{\"nodeName\":\"$node\"}}" \
      --command -- true >/dev/null
  done
  sleep 3
  for node in $(kubectl get nodes -o name | cut -d/ -f2); do
    local limit=$((SECONDS + 60))
    until [ "$(kubectl get pod "probe-$node" -o jsonpath='{.status.phase}')" = Succeeded ]; do
      if [ $SECONDS -gt $limit ]; then bad+=("$node"); break; fi
      sleep 2
    done
    kubectl delete pod "probe-$node" --ignore-not-found --now >/dev/null
  done
  echo "${bad[@]:-}"
}

docker pull -q "$PROBE_SRC" >/dev/null
docker tag "$PROBE_SRC" localhost:30500/probe:1
docker push -q localhost:30500/probe:1 >/dev/null

bad="$(failing_nodes)"
if [ -z "$bad" ]; then echo "All nodes pull from $HOST."; exit 0; fi

for node in $bad; do
  ip="$(kubectl get node "$node" -o jsonpath='{.status.addresses[?(@.type=="InternalIP")].address}')"
  n="${ip##*.}"
  log "$node (node$n) cannot pull from $HOST: adding the mirror to $CONF (the sudo password may be asked)"
  svc=k3s-agent; [ "$n" = 1 ] && svc=k3s
  # If `mirrors:` exists already, a second key would be invalid YAML: insert below it, else add the key.
  ssh_t "node$n" "$SUDO touch $CONF; if $SUDO grep -q '^mirrors:' $CONF; then
      $SUDO sed -i '/^mirrors:/a\\  \"$HOST\":\\n    endpoint:\\n      - \"http://localhost:30500\"' $CONF
    else
      printf 'mirrors:\n  \"$HOST\":\n    endpoint:\n      - \"http://localhost:30500\"\n' | $SUDO tee -a $CONF >/dev/null
    fi; $SUDO systemctl restart $svc"
done
wait_for "all nodes Ready" 180 bash -c "kubectl get nodes --no-headers | awk '\$2!=\"Ready\"{bad=1} END{exit bad}'"
bad="$(failing_nodes)"
[ -z "$bad" ] || die "These nodes still cannot pull from $HOST: $bad"
echo "All nodes pull from $HOST."
