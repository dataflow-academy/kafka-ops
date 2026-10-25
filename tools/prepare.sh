#!/usr/bin/env bash
# Start state "Kafka tools available": the Deployment kafka-tools in the namespace kafka. Idempotent.
. "$(dirname "$0")/../lib/common.sh"
need kubectl; need envsubst
kube_ready || die "kubectl cannot reach the cluster."
apply_tpl "$(dirname "$0")/kafka-tools.yaml"
kubectl -n "$KAFKA_NAMESPACE" rollout status deployment/kafka-tools --timeout=180s
