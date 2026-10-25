#!/usr/bin/env bash
# Removes the kafka-tools Deployment. Idempotent.
. "$(dirname "$0")/../lib/common.sh"
kubectl -n "$KAFKA_NAMESPACE" delete deployment kafka-tools --ignore-not-found
