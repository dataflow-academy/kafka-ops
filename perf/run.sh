#!/usr/bin/env bash
# Runs kafka-producer-perf-test inside the cluster and prints its result.
# Every parameter is an environment variable; the defaults are a plain run.
#
#   PERF_NAME=perf-acks1 PERF_PRODUCER_PROPS="acks=1 linger.ms=20" ./run.sh
#
#   PERF_NAME         Job and KafkaTopic resource name (default perf-<time>)
#   PERF_TOPIC        Kafka topic name (default nordwind.platform.private.$PERF_NAME.event)
#   PERF_PARTITIONS   default 6      PERF_REPLICAS  default 3      PERF_MIN_ISR  default 2
#   PERF_RECORDS      default 1000000
#   PERF_RECORD_SIZE  bytes, default 1024
#   PERF_THROUGHPUT   records/s, -1 = unlimited (default)
#   PERF_PRODUCER_PROPS  space separated key=value, e.g. "acks=1 linger.ms=20 batch.size=131072 compression.type=lz4"
#
# Prepare with `./reset.sh` to remove the topics and Jobs of earlier runs. Run it on node1.
. "$(dirname "$0")/../lib/common.sh"
need kubectl; need envsubst
kube_ready || die "kubectl cannot reach the cluster."
HERE="$(cd "$(dirname "$0")" && pwd)"
export PERF_NAME="${PERF_NAME:-perf-$(date +%H%M%S)}"
export PERF_TOPIC="${PERF_TOPIC:-nordwind.platform.private.${PERF_NAME}.event}" PERF_PARTITIONS="${PERF_PARTITIONS:-6}" \
  PERF_REPLICAS="${PERF_REPLICAS:-3}" PERF_MIN_ISR="${PERF_MIN_ISR:-2}" PERF_RECORDS="${PERF_RECORDS:-1000000}" \
  PERF_RECORD_SIZE="${PERF_RECORD_SIZE:-1024}" PERF_THROUGHPUT="${PERF_THROUGHPUT:--1}" PERF_PRODUCER_PROPS="${PERF_PRODUCER_PROPS:-}"
VARS="\${PERF_NAME} \${PERF_TOPIC} \${PERF_PARTITIONS} \${PERF_REPLICAS} \${PERF_MIN_ISR} \${PERF_RECORDS} \${PERF_RECORD_SIZE} \${PERF_THROUGHPUT} \${PERF_PRODUCER_PROPS}"
N=(-n "$KAFKA_NAMESPACE")

envsubst "$VARS" < "$HERE/topic.yaml" | kubectl "${N[@]}" apply -f - >/dev/null
kubectl "${N[@]}" wait "kafkatopic/$PERF_NAME" --for=condition=Ready --timeout=120s >/dev/null
envsubst "$VARS" < "$HERE/job.yaml" | kubectl "${N[@]}" apply -f - >/dev/null
kubectl "${N[@]}" wait "job/$PERF_NAME" --for=condition=Complete --timeout=900s >/dev/null || { kubectl "${N[@]}" logs "job/$PERF_NAME" | tail -20; die "Perf run failed."; }
kubectl "${N[@]}" logs "job/$PERF_NAME" | tail -3
