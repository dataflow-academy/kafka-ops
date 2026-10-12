#!/usr/bin/env bash
# Removes the wind park: the namespace `windpark` with all applications, the team-owned topics, and the
# topics of the onboarding requests. The cluster stays. Run it on node1. Idempotent.
. "$(dirname "$0")/../lib/common.sh"
need kubectl
kube_ready || { echo "No cluster reachable, nothing to reset."; exit 0; }
kubectl delete namespace windpark --ignore-not-found --wait=true --timeout=180s
kubectl -n "$KAFKA_NAMESPACE" delete kafkatopic --ignore-not-found \
  -l app.kubernetes.io/part-of=wind-park
kubectl -n "$KAFKA_NAMESPACE" delete kafkatopic --ignore-not-found \
  nordwind.scada.public.turbine-telemetry.event nordwind.assets.public.turbine-registry.state nordwind.assets.public.park-registry.state
# Topics that only exist through auto-creation (for example the typo topic of fault F1).
for t in nordwind.scada.public.turbine-telemetery.event windpark_alerts; do
  kubectl -n "$KAFKA_NAMESPACE" exec "${KAFKA_CLUSTER}-broker-0" -- /opt/kafka/bin/kafka-topics.sh \
    --bootstrap-server localhost:9092 --delete --topic "$t" 2>/dev/null || true
done
