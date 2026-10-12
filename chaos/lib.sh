#!/usr/bin/env bash
# Helpers for the failure scripts. Source it after lib/common.sh.
. "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"
NS="$KAFKA_NAMESPACE"
BOOTSTRAP="${BOOTSTRAP:-my-cluster-kafka-bootstrap.$KAFKA_NAMESPACE.svc:9092}"

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

# Scales the operator up and makes sure it notices pods that were deleted while it was away:
# a freshly started operator sometimes sits in a reconciliation that waits for the missing pod.
operator_up() {
  operator_scale 1
  local i
  for i in 1 2 3 4 5 6; do
    sleep 10
    [ "$(kubectl -n "$NS" get pods -l strimzi.io/kind=Kafka --no-headers 2>/dev/null | wc -l)" -ge 6 ] && return 0
  done
  kubectl -n "$NS" delete pod -l strimzi.io/kind=cluster-operator >/dev/null 2>&1 || true
}
operator_scale() { kubectl -n "$NS" scale deployment/strimzi-cluster-operator --replicas="$1" >/dev/null; }
broker_pod()     { echo "my-cluster-broker-$1"; }
node_of_pod()    { kubectl -n "$NS" get pod "$1" -o jsonpath='{.spec.nodeName}'; }

# Kafka command line tools run in the kafka-tools pod (tools/prepare.sh).
kt() { kubectl -n "$NS" exec -i deploy/kafka-tools -- "$@"; }
ensure_tools() { kubectl -n "$NS" get deploy kafka-tools >/dev/null 2>&1 || "$ROOT/tools/prepare.sh" >/dev/null; }
# Number of under-replicated partitions as seen by Kafka.
urp() { timeout 30 kubectl -n "$NS" exec deploy/kafka-tools -- kafka-topics.sh --bootstrap-server "$BOOTSTRAP" --describe --under-replicated-partitions 2>/dev/null | grep -c Topic || true; }

# State of the active failure (so heal.sh knows what to undo). A ConfigMap, not a file, so it survives a change of VM.
state_set() { kubectl -n "$NS" create configmap chaos-state --from-literal="$1=$2" --dry-run=client -o yaml | kubectl -n "$NS" apply -f - >/dev/null 2>&1 || kubectl -n "$NS" patch configmap chaos-state --type merge -p "{\"data\":{\"$1\":\"$2\"}}" >/dev/null; }
state_get() { kubectl -n "$NS" get configmap chaos-state -o "jsonpath={.data.$1}" 2>/dev/null || true; }

# Runs a command with root rights on a node over ssh. Participants do not have
# passwordless sudo; the password comes from the trainer. Tests set SUDO="sudo -A".
host_sudo() {
  local node="$1"; shift
  local n="${node##*node}"
  if [ -n "${SUDO:-}" ]; then $NODE_SSH "node$n" "$SUDO $*"; return; fi
  if $NODE_SSH "node$n" "sudo -n true" 2>/dev/null; then $NODE_SSH "node$n" "sudo $*"; return; fi
  if [ -z "${SUDO_PASSWORD:-}" ]; then read -rsp "sudo password for node$n (ask the trainer): " SUDO_PASSWORD; echo; fi
  $NODE_SSH "node$n" "echo '$SUDO_PASSWORD' | sudo -S -p '' $*"
}
