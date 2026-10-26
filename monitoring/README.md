# Monitoring

Plain Prometheus (no Prometheus Operator), Grafana and Kafka UI as Deployments in the namespace `kafka`.
Prometheus finds its targets through the Kubernetes API with the same relabeling as the example `PodMonitor`s
of Strimzi, so the dashboards find the labels they expect. Grafana is provisioned with the dashboards
`strimzi-kafka`, `strimzi-kraft`, `strimzi-kafka-exporter` and `strimzi-operators` from the pinned Strimzi release
(`dashboards/`; Strimzi 1.1.0; replace them from the same release when the Strimzi version changes) and `wind-park.json`.
Data lives in an `emptyDir`: a restart of Prometheus starts from empty.
