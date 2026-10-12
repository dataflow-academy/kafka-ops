#!/usr/bin/env bash
# Is the cluster healthy? Prints what is wrong and exits with 1, or prints "healthy" and exits with 0.
#   - all nodes Ready
#   - the operator runs
#   - Kafka is Ready and all brokers and controllers run
#   - no under-replicated and no unavailable partitions (as Kafka sees them, not as the Kafka resource says)
#   - a new KafkaTopic becomes Ready (so the operators watch the right namespace and the controllers have a quorum)
. "$(dirname "$0")/lib.sh"
kube_ready || die "kubectl cannot reach the cluster."
problems=0
bad() { echo "PROBLEM: $*"; problems=$((problems + 1)); }

not_ready=$(kubectl get nodes --no-headers | awk '$2 != "Ready" {print $1}' | paste -sd' ')
[ -z "$not_ready" ] || bad "nodes not Ready: $not_ready"

kubectl -n "$NS" get pods -l strimzi.io/kind=cluster-operator --no-headers 2>/dev/null | grep -q ' 1/1 ' || bad "the Strimzi operator is not running"
kubectl -n "$NS" wait "kafka/$KAFKA_CLUSTER" --for=condition=Ready --timeout=5s >/dev/null 2>&1 || bad "the Kafka resource is not Ready"

n=$(kubectl -n "$NS" get pods -l strimzi.io/kind=Kafka --no-headers 2>/dev/null | grep -c ' 1/1 .*Running' || true)
[ "$n" -ge 6 ] || bad "only $n of 6 broker and controller pods are running and ready"

ensure_tools
if out=$(timeout 40 kubectl -n "$NS" exec deploy/kafka-tools -- kafka-topics.sh --bootstrap-server "$BOOTSTRAP" --describe --under-replicated-partitions 2>&1); then
  c=$(grep -c Topic <<<"$out" || true); [ "$c" = 0 ] || bad "$c under-replicated partitions"
else bad "cannot ask Kafka for under-replicated partitions"; fi
if out=$(timeout 40 kubectl -n "$NS" exec deploy/kafka-tools -- kafka-topics.sh --bootstrap-server "$BOOTSTRAP" --describe --unavailable-partitions 2>&1); then
  c=$(grep -c Topic <<<"$out" || true); [ "$c" = 0 ] || bad "$c unavailable partitions"
else bad "cannot ask Kafka for unavailable partitions"; fi

probe=check-probe
kubectl -n "$NS" delete kafkatopic "$probe" --ignore-not-found >/dev/null 2>&1
kubectl apply -f - >/dev/null <<YAML
apiVersion: kafka.strimzi.io/v1
kind: KafkaTopic
metadata: { name: $probe, namespace: $NS, labels: { strimzi.io/cluster: $KAFKA_CLUSTER } }
spec: { topicName: chaos.check.probe, partitions: 1, replicas: 3 }
YAML
kubectl -n "$NS" wait kafkatopic/$probe --for=condition=Ready --timeout=60s >/dev/null 2>&1 || bad "a new KafkaTopic does not become Ready"
kubectl -n "$NS" delete kafkatopic "$probe" --wait=false >/dev/null 2>&1

if [ "$problems" = 0 ]; then echo "healthy"; else exit 1; fi
