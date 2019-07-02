package main

import org.apache.spark.SparkConf
import org.apache.spark.sql.SparkSession
import org.apache.spark.sql.types._
import org.apache.spark.sql.functions._
import org.apache.spark.sql.streaming.Trigger

object Main {

  def main(args: Array[String]) {

    val conf = new SparkConf()
      .setAppName("Structured Streaming from Event Stream to COS")

    val spark = SparkSession
      .builder()
      .config(conf)
      .getOrCreate()

    import spark.implicits._

    val bucketName = conf.get("spark.s3_bucket")

    // arbitrary name for refering to the cos settings from this code
    val serviceName = "myservicename"

    val sc = spark.sparkContext
    val s3Url = "cos://${bucketName}." + args(0)

    //Define the schema of the incoming data 
    val schema = new StructType()
      .add("GENDER", StringType)
      .add("AGE", IntegerType)
      .add("MARITAL_STATUS", StringType)
      .add("PROFESSION", StringType)
      .add("IS_TENT", StringType)
      .add("PRODUCT_LINE", StringType)
      .add("PURCHASE_AMOUNT", DoubleType)

    //read the kafka stream 
    val df = spark.readStream.
      format("kafka").
      option("kafka.bootstrap.servers", conf.get("spark.kafka_bootstrap_servers")).
      option("subscribe", "webserver").
      option("kafka.security.protocol", "SASL_SSL").
      option("kafka.sasl.mechanism", "PLAIN").
      option("kafka.ssl.protocol", "TLSv1.2").
      option("kafka.ssl.enabled.protocols", "TLSv1.2").
      option("failOnDataLoss", "false").
      load()

    val dataDf = df.selectExpr("CAST(value AS STRING) as json").
      select( from_json($"json", schema=schema).as("data")).
      select("data.*").
      filter($"PROFESSION".isNotNull).   //Filter out the rows where Profession is null 
      filter($"PURCHASE_AMOUNT".isNotNull).  //Filter out the rows where Purchase Amount is null 
      filter($"GENDER" === "M") //Filter out the rows where Gender is Male
      

    val trigger_time_ms = conf.get("spark.trigger_time_ms").toInt

    //Write the stream to the COS bucket as a csv file 
    dataDf.
      writeStream.
      format("parquet"). //This stores the data on COS as a Parquet file. it can be changed to "csv" or "json" if required. 
      trigger(Trigger.ProcessingTime(trigger_time_ms)).
      option("checkpointLocation", s"${s3Url}/checkpoint").
      option("path", s"${s3Url}/data").
      option("header", "true"). 
      start()

    //Wait for all streams to finish
    spark.streams.awaitAnyTermination()
  }
}
