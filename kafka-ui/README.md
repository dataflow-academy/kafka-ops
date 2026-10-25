# Kafka UI

`kafka-ui.yaml` runs [Kafka UI](https://github.com/kafbat/kafka-ui) in the namespace `kafka`, on NodePort 30800 of
every node, for whichever Kafka cluster runs in the namespace (`hello` in the first lab, `my-cluster` later): it
bootstraps through the Service `kafka-ui-bootstrap`, which selects the broker pods of any Strimzi cluster there. The first lab applies it with `kubectl apply -f`;
`hello/prepare.sh` and `monitoring/install.sh` do the same.
