import com.ibm.metaindex.metadata.metadatastore.parquet.{Parquet, ParquetMetadataBackend}
import com.ibm.metaindex.{MetaIndexManager, Registration}
import org.apache.log4j.{Level, LogManager}
import org.apache.spark.sql.SparkSession

/**
  * Sample of indexing and querying hive tables
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
    // For more info on how to config credentials see https://github.com/CODAIT/stocator
    // see https://cloud.ibm.com/docs/services/cloud-object-storage?topic=cloud-object-storage-endpoints for the list of endpoints
    // make sure you choose the private endpoint of your bucket
    spark.sparkContext.hadoopConfiguration.set("fs.cos.service.endpoint" ,"https://s3.private.us-south.cloud-object-storage.appdomain.cloud")
    spark.sparkContext.hadoopConfiguration.set("fs.cos.service.access.key", "<accessKey>")
    spark.sparkContext.hadoopConfiguration.set("fs.cos.service.secret.key","<secretKey>")

    // inject the data skipping rule
    MetaIndexManager.injectDataSkippingRule(spark)

    // enable data skipping
    MetaIndexManager.enableFiltering(spark)

    // data set and metadata location
    val dataset_location = "cos://mybucket.service/location/to/my/data"
    val md_base_path = "cos://mybucket.service/location/to/my/base/metdata"

    // set the base metadata location in the database
    spark.sql(s"ALTER DATABASE default SET DBPROPERTIES ('spark.ibm.metaindex.parquet.mdlocation'='${md_base_path}')")

    // drop table if it already exists
    spark.sql("DROP TABLE IF EXISTS metergen")
    // create the table
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
          LOCATION '${dataset_location}'
          TBLPROPERTIES ('parquet.compression'='SNAPPY' , 'transactional'='false')"""
    spark.sql(createTable)
    spark.sql("SHOW TABLES").show()

    // Recovering the partitions
    spark.sql("ALTER TABLE metergen RECOVER PARTITIONS")

    // setup the JVM parameters for MetaIndexManager - In this example, we will set the base location to be retrieved
    // from the database properties
    Registration.setDefaultMetaDataStore(Parquet)
    val jvmParameters = new java.util.HashMap[String, String]()
    jvmParameters.put("spark.ibm.metaindex.parquet.mdlocation", "default")
    jvmParameters.put("spark.ibm.metaindex.parquet.mdlocation.type", "HIVE_DB_NAME")
    MetaIndexManager.setConf(jvmParameters)

    // create MetaIndexManager instance with Parquet Metadatastore backend
    // and setting the table name in the MetaIndexManager properties so the metadata location
    // will be added automatically to the table properties
    val im = new MetaIndexManager(spark, "default.metergen", ParquetMetadataBackend)
    val jmap = new java.util.HashMap[String, String]()
    jmap.put("spark.ibm.metaindex.parquet.mdlocation", "default.metergen")
    jmap.put("spark.ibm.metaindex.parquet.mdlocation.type", "HIVE_TABLE_NAME")
    im.setMetadataStoreParams(jmap)

    // remove existing index first
    if (im.isIndexed()) {
      im.removeIndex()
    }

    // indexing
    println("Building the index:")
    im.indexBuilder().addMinMaxIndex("temp").addValueListIndex("city").addBloomFilterIndex("vid").build().show(false)

    // for refresh use
    // im.refreshIndex().show(false)

    // view index status
    im.getIndexStats().show(false)

    // inject the data skipping rule
    MetaIndexManager.injectDataSkippingRule(spark)

    // enable data skipping
    MetaIndexManager.enableFiltering(spark)

    // query the table and view skipping stats
    spark.sql("select * from metergen where temp > 30").show()

    // get aggregated stats
    MetaIndexManager.getLatestQueryAggregatedStats(spark).show()

    // (optional) clear the stats for the next query (otherwise, stats will acummulate)
    MetaIndexManager.clearStats()    
  }
}
