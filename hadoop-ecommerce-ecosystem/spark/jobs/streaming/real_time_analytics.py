from pyspark.sql import SparkSession
from pyspark.sql.functions import col, from_json, to_timestamp
from pyspark.sql.types import StructType, StructField, StringType, LongType, IntegerType
import argparse


def parse_args():
    parser = argparse.ArgumentParser()
    parser.add_argument("--bootstrap", default="hd-master:9092")
    parser.add_argument("--topic", default="user-events")
    parser.add_argument("--output", default="/data/events/structured")
    parser.add_argument("--checkpoint", default="/checkpoints/real_time_analytics")
    return parser.parse_args()


def main():
    args = parse_args()

    spark = (
        SparkSession.builder.appName("real_time_analytics")
        .config("spark.sql.session.timeZone", "UTC")
        .getOrCreate()
    )

    schema = StructType(
        [
            StructField("user_id", IntegerType(), True),
            StructField("event", StringType(), True),
            StructField("product_id", IntegerType(), True),
            StructField("ts", StringType(), True),
        ]
    )

    raw_stream = (
        spark.readStream.format("kafka")
        .option("kafka.bootstrap.servers", args.bootstrap)
        .option("subscribe", args.topic)
        .option("startingOffsets", "latest")
        .load()
    )

    parsed = (
        raw_stream.selectExpr("CAST(value AS STRING) AS json")
        .select(from_json(col("json"), schema).alias("data"))
        .select("data.*")
        .withColumn("event_time", to_timestamp(col("ts")))
    )

    query = (
        parsed.writeStream.outputMode("append")
        .format("parquet")
        .option("path", args.output)
        .option("checkpointLocation", args.checkpoint)
        .start()
    )

    query.awaitTermination()


if __name__ == "__main__":
    main()

