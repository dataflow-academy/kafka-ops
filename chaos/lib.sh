#!/usr/bin/env bash
# Helpers for the failure scripts. Source it after lib/common.sh.
. "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"
NS="$KAFKA_NAMESPACE"
BOOTSTRAP="${BOOTSTRAP:-nordwind-kafka-kafka-bootstrap.$KAFKA_NAMESPACE.svc:9092}"

# Runs a shell command in the namespaces of a node (mount, network, ...) through a
# short-lived privileged pod, so the scripts need neither ssh nor sudo.
# usage: on_node <kubernetes node name> '<command run as root on the node>'
on_node() {
  local node="$1" cmd="$2" name="chaos-node-$RANDOM"
  kubectl -n "$NS" run "$name" --restart=Never --rm -i --quiet --labels=app=chaos-helper \
    --image="$(helper_image)" --overrides="$(cat <<JSON
{"spec":{"nodeName":"$node","hostPID":true,"terminationGracePeriodSeconds":0,
 "containers":[{"name":"$name","image":"$(helper_image)","imagePullPolicy":"IfNotPresent",
  "command":["nsenter","-t","1","-m","-u","-i","-n","-p","--","sh","-c",$(printf '%s' "$cmd" | jq -Rs .)],
  "securityContext":{"privileged":true}}]}}
JSON
)" 2>&1 | grep -v '^pod ".*" deleted' || true
}

# Already on every node: k3s ships busybox for its volume provisioner, and busybox has nsenter.
helper_image() { echo "rancher/mirrored-library-busybox:1.37.0"; }

# Scales the operator up and makes it notice pods that were deleted while it was away. A freshly started
# operator only recreates a missing pod when its StrimziPodSet changes (otherwise after about five minutes), so
# the PodSets get an annotation.
operator_up() {
  operator_scale 1
  kubectl -n "$NS" rollout status deployment/strimzi-cluster-operator --timeout=180s >/dev/null
  sleep 15
  nudge_podsets
}
nudge_podsets() {
  local ps
  for ps in $(kubectl -n "$NS" get strimzipodset -o name 2>/dev/null); do
    kubectl -n "$NS" annotate "$ps" "training/nudge=$(date +%s)" --overwrite >/dev/null
  done
}
operator_scale() { kubectl -n "$NS" scale deployment/strimzi-cluster-operator --replicas="$1" >/dev/null; }
broker_pod()     { echo "nordwind-kafka-broker-$1"; }
node_of_pod()    { kubectl -n "$NS" get pod "$1" -o jsonpath='{.spec.nodeName}'; }

# Kafka command line tools run in the kafka-tools pod (tools/prepare.sh).
kt() { kubectl -n "$NS" exec -i deploy/kafka-tools -- "$@"; }
ensure_tools() { kubectl -n "$NS" get deploy kafka-tools >/dev/null 2>&1 || "$ROOT/tools/prepare.sh" >/dev/null; }
# Number of under-replicated partitions as seen by Kafka.
urp() { timeout 30 kubectl -n "$NS" exec deploy/kafka-tools -- kafka-topics.sh --bootstrap-server "$BOOTSTRAP" --describe --under-replicated-partitions 2>/dev/null | grep -c Topic || true; }

# State of the active failure (so heal.sh knows what to undo). A ConfigMap, not a file, so it survives a change of VM.
state_set() { kubectl -n "$NS" create configmap chaos-state --from-literal="$1=$2" --dry-run=client -o yaml | kubectl -n "$NS" apply -f - >/dev/null 2>&1 || kubectl -n "$NS" patch configmap chaos-state --type merge -p "{\"data\":{\"$1\":\"$2\"}}" >/dev/null; }
state_get() { kubectl -n "$NS" get configmap chaos-state -o "jsonpath={.data.$1}" 2>/dev/null || true; }

# Runs a command with root rights on a node (`on` in lib/common.sh: locally on node1, else ssh $IP.N). The lab VMs
# have passwordless sudo; tests set SUDO="sudo -A" for their wrapper.
host_sudo() {
  local node="$1"; shift
  local n="${node##*node}"
  on "node$n" "${SUDO:-sudo} $*"
}
