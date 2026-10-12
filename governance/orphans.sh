#!/usr/bin/env bash
# Lists topics that exist in Kafka but have no KafkaTopic resource: nobody declared them, so nobody reviewed them.
# (Internal topics starting with __ are left out.)
. "$(dirname "$0")/../lib/common.sh"
NS="$KAFKA_NAMESPACE"
declared=$(kubectl -n "$NS" get kafkatopic -o custom-columns=T:.spec.topicName,N:.metadata.name --no-headers | awk '{print ($1 == "<none>") ? $2 : $1}' | sort)
existing=$(kubectl -n "$NS" exec deploy/kafka-tools -- kafka-topics.sh --bootstrap-server "my-cluster-kafka-bootstrap:9092" --list | grep -v '^__' | sort)
comm -13 <(echo "$declared") <(echo "$existing")
