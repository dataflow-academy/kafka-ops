# Performance tests

`./run.sh` creates a topic (Kafka name `nordwind.platform.private.<PERF_NAME>.event`, so it passes the naming policy of the governance lab; `PERF_TOPIC` overrides it), runs one `kafka-producer-perf-test` as a Job inside the cluster and prints the result line.
All parameters are environment variables, documented at the top of `run.sh`.

    PERF_NAME=perf-acks1 PERF_PRODUCER_PROPS="acks=1" ./run.sh
    PERF_PARTITIONS=1 PERF_RECORDS=500000 ./run.sh

`./reset.sh` removes all perf topics and Jobs.
