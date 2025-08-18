import json
import time
import argparse
from kafka import KafkaProducer


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--bootstrap", default="localhost:9092")
    parser.add_argument("--topic", default="user-events")
    parser.add_argument("--file", default="data/sample-data/user-events.json")
    args = parser.parse_args()

    producer = KafkaProducer(
        bootstrap_servers=args.bootstrap,
        value_serializer=lambda v: json.dumps(v).encode("utf-8"),
    )

    with open(args.file, "r", encoding="utf-8") as f:
        for line in f:
            event = json.loads(line)
            producer.send(args.topic, event)
            print("Sent:", event)
            time.sleep(0.2)

    producer.flush()
    producer.close()


if __name__ == "__main__":
    main()

