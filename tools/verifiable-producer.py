#!/usr/bin/env python3
"""Writes numbered records into a topic and prints one table row per acknowledged record and one line per failure.

    verifiable-producer.py --bootstrap-server HOST:PORT --topic TOPIC --acks {all,-1,1,0} [--throughput N]

Based on verifiable-producer.py of github.com/kafka-trainings/kafka-training-resources.
With acks=all the producer is idempotent.
"""
import argparse
import sys
import time

from confluent_kafka import Producer


def print_table_header():
    print("┌──────┬──────────────┬───────┬────────────┬───────────────┐")
    print("│ Part │ Offset       │ Key   │ Value      │ Timestamp     │")
    print("├──────┼──────────────┼───────┼────────────┼───────────────┤")


def delivery_report(err, msg):
    """Called once for each message produced to indicate delivery result."""
    key_str = msg.key().decode("utf-8") if msg.key() else "None"
    value_str = msg.value().decode("utf-8") if msg.value() else "None"

    if err:
        print(f"Message delivery failed: {value_str}: {err.str()}", flush=True)
        return

    # Print table header if it's the first message
    if not hasattr(delivery_report, "header_printed"):
        print_table_header()
        delivery_report.header_printed = True

    # Print table row
    partition_str = str(msg.partition()) if msg.partition() is not None else "?"
    offset_str = str(msg.offset()) if msg.offset() is not None and msg.offset() >= 0 else "?"
    timestamp_str = str(msg.timestamp()[1]) if msg.timestamp()[1] is not None else "?"
    print(f"│ {partition_str:^4} │ {offset_str:>12} │ {key_str:<5} │ {value_str:>10} │ {timestamp_str:>13} │", flush=True)


def acks_value(text):
    """acks as Kafka knows it: all (or -1), 1 or 0."""
    value = text.strip().lower()
    if value == "-1":
        value = "all"
    if value not in ("all", "1", "0"):
        raise argparse.ArgumentTypeError(f"acks must be all, -1, 1 or 0, not {text!r}")
    return value


def main():
    parser = argparse.ArgumentParser(description="Kafka Verifiable Producer")
    parser.add_argument("--topic", required=True, help="Produce messages to this topic.")
    parser.add_argument("--max-messages", type=int, default=-1,
                        help="Produce this many messages. If -1, produce messages until killed. (default: -1)")
    parser.add_argument("--throughput", type=int, default=1,
                        help="Throttle message throughput to THROUGHPUT messages/sec. (default: 1)")
    parser.add_argument("--acks", type=acks_value, default="1",
                        help="Acks required on each produced message: all (or -1), 1 or 0. (default: 1)")
    parser.add_argument("--producer_config", help="Producer config properties file.")
    parser.add_argument("--value-prefix", help="Each produced value will have this prefix with a dot separator.")
    parser.add_argument("--repeating-keys", type=int,
                        help="Each produced record will have a key starting at 0 increment by 1 up to the number specified (exclusive), then reset to 0.")
    parser.add_argument("--bootstrap-server", required=True,
                        help="The server(s) to connect to. Comma-separated list of Kafka brokers in the form HOST1:PORT1,HOST2:PORT2,...")

    args = parser.parse_args()

    # Report a rejected record after a few seconds with the broker's error, not after minutes as a timeout.
    conf = {"bootstrap.servers": args.bootstrap_server,
            "partitioner": "murmur2_random",
            "acks": args.acks,
            "retries": 5,
            "retry.backoff.ms": 1000,
            "retry.backoff.max.ms": 1000}

    # Idempotence needs acks=all; with 1 or 0 it stays off.
    if args.acks == "all":
        conf["enable.idempotence"] = True

    if args.producer_config:
        with open(args.producer_config, "r") as f:
            for line in f:
                line = line.strip()
                if line and not line.startswith("#"):
                    key, value = line.split("=", 1)
                    conf[key.strip()] = value.strip()

    producer = Producer(conf)

    key_counter = 0
    message_counter = 0
    start_time = time.time()
    try:
        while args.max_messages == -1 or message_counter < args.max_messages:
            if args.repeating_keys:
                key = str(key_counter).encode("utf-8")
                key_counter = (key_counter + 1) % args.repeating_keys
            else:
                key = None

            value = f"{args.value_prefix}.{message_counter}" if args.value_prefix else str(message_counter)
            producer.produce(args.topic, key=key, value=value, callback=delivery_report)
            producer.poll(0)

            message_counter += 1

            if args.throughput > 0:
                elapsed_time = time.time() - start_time
                expected_time = message_counter / args.throughput
                if elapsed_time < expected_time:
                    time.sleep(expected_time - elapsed_time)
                    producer.poll(0)
    except KeyboardInterrupt:
        pass
    finally:
        # Do not hang on Ctrl+C while no broker accepts the records.
        producer.flush(5)
        sys.exit(0)


if __name__ == "__main__":
    main()
