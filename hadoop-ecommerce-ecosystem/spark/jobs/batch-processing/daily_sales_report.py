from pyspark.sql import SparkSession
from pyspark.sql.functions import col, sum as _sum
import argparse


def parse_args():
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", required=True, help="Path to orders.csv")
    parser.add_argument("--products", required=True, help="Path to products.csv")
    parser.add_argument("--output", required=True, help="Output directory")
    return parser.parse_args()


def main():
    args = parse_args()

    spark = (
        SparkSession.builder.appName("daily_sales_report")
        .config("spark.sql.session.timeZone", "UTC")
        .getOrCreate()
    )

    orders_df = (
        spark.read.option("header", True)
        .option("inferSchema", True)
        .csv(args.input)
    )

    products_df = (
        spark.read.option("header", True)
        .option("inferSchema", True)
        .csv(args.products)
    )

    joined = (
        orders_df.join(products_df, on=["product_id"], how="left")
        .withColumn("revenue", col("quantity") * col("price"))
    )

    report = (
        joined.groupBy("order_date")
        .agg(_sum("revenue").alias("daily_revenue"))
        .orderBy("order_date")
    )

    report.write.mode("overwrite").option("header", True).csv(args.output)

    spark.stop()


if __name__ == "__main__":
    main()

