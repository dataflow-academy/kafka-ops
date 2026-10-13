# Performance tests

`./run.sh` creates a topic, runs one `kafka-producer-perf-test` as a Job inside the cluster and prints the result line.
All parameters are environment variables, documented at the top of `run.sh`.

    PERF_NAME=perf-acks1 PERF_PRODUCER_PROPS="acks=1" ./run.sh
    PERF_PARTITIONS=1 PERF_RECORDS=500000 ./run.sh

`./reset.sh` removes all perf topics and Jobs.
