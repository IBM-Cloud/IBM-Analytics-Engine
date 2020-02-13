import com.ibm.metaindex.metadata.metadatastore.parquet.{Parquet, ParquetMetadataBackend}
import com.ibm.metaindex.{MetaIndexManager, Registration}
import org.apache.log4j.{Level, LogManager, Logger}
import org.apache.spark.sql.SparkSession

/**
  * Sample of indexing and querying hive table using Parquet Metadatastore
  */
object MetaIndexManagerSampleHive {
  val logger = Logger.getLogger(this.getClass)

  def main(args: Array[String]) {
    val spark = SparkSession
      .builder()
      .appName("MetaIndexManager Hive Sample")
      .enableHiveSupport()
      .getOrCreate()

    // (optional) set log level to debug specifically for metaindex package - to view the skipped objects
    LogManager.getLogger("com.ibm.metaindex").setLevel(Level.DEBUG)

    // Setup the environment
    // configure Stocator
    spark.sparkContext.hadoopConfiguration.set("fs.stocator.scheme.list", "cos")
    spark.sparkContext.hadoopConfiguration.set("fs.cos.impl", "com.ibm.stocator.fs.ObjectStoreFileSystem")
    spark.sparkContext.hadoopConfiguration.set("fs.stocator.cos.impl", "com.ibm.stocator.fs.cos.COSAPIClient")
    spark.sparkContext.hadoopConfiguration.set("fs.stocator.cos.scheme", "cos")

    // for more info on how to config credentials see https://github.com/CODAIT/stocator
    // see https://cloud.ibm.com/docs/services/cloud-object-storage?topic=cloud-object-storage-endpoints for the list of endpoints
    spark.sparkContext.hadoopConfiguration.set("fs.cos.service.endpoint" ,"http://s3.us-south.objectstorage.softlayer.net")
    spark.sparkContext.hadoopConfiguration.set("fs.cos.$serviceName.access.key", "<accessKey>")
    spark.sparkContext.hadoopConfiguration.set("fs.cos.service.secret.key","<secretKey>")

    // dataset location
    val input_path = "cos://mybucket.service/location/to/my/data"
    // metadata base location
    val md_base_path = "cos://mybucket.service/location/to/my/base/metdata"

    // set the base metadata location in the database
    spark.sql(s"ALTER DATABASE default SET DBPROPERTIES ('spark.ibm.metaindex.parquet.mdlocation'='${md_base_path}')")

    // drop table if it already exists
    spark.sql("drop table if exists metergen")
    // create hive metastore table
    val createTable = s"""CREATE EXTERNAL TABLE IF NOT EXISTS metergen (
            vid String,
            date Timestamp,
            index Double,
            sumHC Double,
            sumHP Double,
            type String,
            size Integer,
            temp Double,
            city String,
            region Integer,
            lat Double,
            lng Double
          )
          PARTITIONED BY (dt String)
          STORED AS PARQUET
          LOCATION '${input_path}'
          TBLPROPERTIES ('parquet.compression'='SNAPPY' , 'transactional'='false')"""
    spark.sql(createTable)

    // Recovering the partitions
    spark.sql("ALTER TABLE metergen RECOVER PARTITIONS")

    // Setup the JVM parameters for MetaIndexManager and enable skipping
    MetaIndexManager.injectDataSkippingRule(spark)
    // set Parquet as the default metadataStore
    Registration.setDefaultMetaDataStore(Parquet)
    // Set the default metadata location to be a base path defined in the database
    val jvmParameters = new java.util.HashMap[String, String]()
    jvmParameters.put("spark.ibm.metaindex.parquet.mdlocation", "default")
    jvmParameters.put("spark.ibm.metaindex.parquet.mdlocation.type", "HIVE_DB_NAME")
    MetaIndexManager.setConf(jvmParameters)
    // Enable data skipping
    MetaIndexManager.enableFiltering(spark)

    // index the dataset - using the table name
    val im = new MetaIndexManager(spark, "default.metergen", ParquetMetadataBackend)
    val jmap = new java.util.HashMap[String, String]()
    // During indexing the path in the table is not yet defined
    // so there will be a fall back to db base location (and if it doesn't exist to the JVM base location)
    jmap.put("spark.ibm.metaindex.parquet.mdlocation", "default.metergen")
    jmap.put("spark.ibm.metaindex.parquet.mdlocation.type", "HIVE_TABLE_NAME")
    im.setMetadataStoreParams(jmap)

    // remove existing index first
    if (im.isIndexed()) {
      im.removeIndex()
    }

    // Build the index
    println("Building the index:")
    im.indexBuilder()
      .addMinMaxIndex("temp")
      .addValueListIndex("city")
      .addBloomFilterIndex("vid")
      .build()

    // for refresh use
    //im.refreshIndex()

    // to view the index status use
    im.getIndexStats().show()

    // Query the table and view skipping stats
    spark.sql("select * from metergen where temp > 30").show()

    MetaIndexManager.getLatestQueryAggregatedStats(spark).show()
  }
}
