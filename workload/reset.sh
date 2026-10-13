#!/usr/bin/env bash
# Removes the wind park workload and its topic (the cluster stays). Run it on
# node1. Idempotent. The consumer group disappears with its last member.
. "$(dirname "$0")/../lib/common.sh"
need kubectl
kube_ready || { echo "No cluster reachable, nothing to reset."; exit 0; }
N=(-n "$KAFKA_NAMESPACE")
kubectl "${N[@]}" delete deployment -l app.kubernetes.io/part-of=wind-park --ignore-not-found
kubectl "${N[@]}" delete configmap -l app.kubernetes.io/part-of=wind-park --ignore-not-found
kubectl "${N[@]}" delete kafkatopic nordwind.scada.public.turbine-telemetry-json.event --ignore-not-found
