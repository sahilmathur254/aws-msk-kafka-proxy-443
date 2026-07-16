#!/usr/bin/env python3
"""Transactional produce/read-committed validation through the port-443 proxy."""

from __future__ import annotations

import os
import sys
import time
import uuid
from pathlib import Path

from confluent_kafka import Consumer, KafkaError, Producer
from confluent_kafka.admin import AdminClient, NewTopic


def read_properties(path: str) -> dict[str, str]:
    properties: dict[str, str] = {}
    for raw_line in Path(path).read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#"):
            continue
        key, separator, value = line.partition("=")
        if not separator:
            raise ValueError(f"Invalid property line: {raw_line!r}")
        properties[key.strip()] = value.strip()
    return properties


def base_config() -> dict[str, str]:
    bootstrap = os.environ["BOOTSTRAP_SERVER"]
    kcat_config = os.environ["KCAT_CONFIG"]
    config = read_properties(kcat_config)
    config["bootstrap.servers"] = bootstrap
    return config


def main() -> int:
    config = base_config()
    topic = os.getenv("TEST_TOPIC", f"proxy-443-txn-{int(time.time())}-{os.getpid()}")
    record = f"transactional-{uuid.uuid4()}"

    admin = AdminClient(config)
    futures = admin.create_topics([NewTopic(topic, num_partitions=3, replication_factor=1)])
    try:
        futures[topic].result(30)
    except Exception as exc:  # TopicExists is acceptable for an explicitly reused TEST_TOPIC.
        if "TOPIC_ALREADY_EXISTS" not in str(exc):
            raise

    producer_config = dict(config)
    producer_config.update(
        {
            "transactional.id": f"proxy-443-{uuid.uuid4()}",
            "enable.idempotence": True,
            "acks": "all",
        }
    )
    producer = Producer(producer_config)
    producer.init_transactions(30)
    producer.begin_transaction()
    producer.produce(topic, value=record.encode("utf-8"))
    producer.flush(30)
    producer.commit_transaction(30)

    consumer_config = dict(config)
    consumer_config.update(
        {
            "group.id": f"proxy-443-txn-check-{uuid.uuid4()}",
            "auto.offset.reset": "earliest",
            "enable.auto.commit": False,
            "isolation.level": "read_committed",
        }
    )
    consumer = Consumer(consumer_config)
    consumer.subscribe([topic])

    deadline = time.time() + 45
    found = False
    try:
        while time.time() < deadline:
            message = consumer.poll(1.0)
            if message is None:
                continue
            if message.error():
                if message.error().code() == KafkaError._PARTITION_EOF:
                    continue
                raise RuntimeError(message.error())
            if message.value().decode("utf-8") == record:
                found = True
                break
    finally:
        consumer.close()

    if os.getenv("KEEP_TEST_TOPIC") != "1":
        admin.delete_topics([topic], operation_timeout=30)[topic].result(45)

    if not found:
        print("FAIL: committed transactional record was not consumed", file=sys.stderr)
        return 1

    print(f"PASS: transaction committed and read through {os.environ['BOOTSTRAP_SERVER']}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
