import com.ibm.metaindex.metadata.metadatastore.parquet.{Parquet, ParquetMetadataBackend}
import com.ibm.metaindex.{MetaIndexManager, Registration}
import org.apache.log4j.{Level, LogManager}
import org.apache.spark.sql.SparkSession

/**
  * Sample of indexing and querying data sets on COS
  */
object MetaIndexManagerSample {
  def main(args: Array[String]) {
    val spark = SparkSession
      .builder()
      .appName("MetaIndexManager Sample")
      .getOrCreate()

    // (optional) set log level to debug specifically for metaindex package - to view the skipped objects
    LogManager.getLogger("com.ibm.metaindex").setLevel(Level.DEBUG)

    // setup the environment
    // configure Stocator
    // for more info on how to config credentials see https://github.com/CODAIT/stocator
    // see https://cloud.ibm.com/docs/services/cloud-object-storage?topic=cloud-object-storage-endpoints for the list of endpoints
    // make sure you choose the private endpoint of your bucket
    spark.sparkContext.hadoopConfiguration.set("fs.cos.service.endpoint" ,"https://s3.private.us-south.cloud-object-storage.appdomain.cloud")
    spark.sparkContext.hadoopConfiguration.set("fs.cos.service.access.key", "<accessKey>")
    spark.sparkContext.hadoopConfiguration.set("fs.cos.service.secret.key","<secretKey>")

    // data set and metadata location
    val dataset_location = "cos://mybucket.service/location/to/my/data"
    val md_base_path = "cos://mybucket.service/location/to/my/base/metdata"

    // setup the JVM parameters for MetaIndexManager - In this example, we will set the JVM wide parameter to a
    // base path to store all of the indexes.
    Registration.setDefaultMetaDataStore(Parquet)
    val jvmParameters = new java.util.HashMap[String, String]()
    jvmParameters.put("spark.ibm.metaindex.parquet.mdlocation", md_base_path)
    jvmParameters.put("spark.ibm.metaindex.parquet.mdlocation.type", "EXPLICIT_BASE_PATH_LOCATION")
    MetaIndexManager.setConf(jvmParameters)

    // create MetaIndexManager instance with Parquet Metadatastore backend
    val reader = spark.read.format("parquet")
    val im = new MetaIndexManager(spark, dataset_location, ParquetMetadataBackend)

    // remove existing index first
    if (im.isIndexed()) {
      im.removeIndex()
    }

    // indexing
    println("Building the index:")
    im.indexBuilder().addMinMaxIndex("temp").addValueListIndex("city").addBloomFilterIndex("vid").build(reader).show(false)

    // for refresh use
    // im.refreshIndex(reader).show(false)

    // view index status
    im.getIndexStats(reader).show(false)

    // inject the data skipping rule
    MetaIndexManager.injectDataSkippingRule(spark)

    // enable data skipping
    MetaIndexManager.enableFiltering(spark) 
    
    // query the table and view skipping stats
    val df = reader.load(dataset_location)
    df.createOrReplaceTempView("metergen")
    spark.sql("select * from metergen where temp > 30").show()

    MetaIndexManager.getLatestQueryAggregatedStats(spark).show(false)

    // (optional) clear the stats for the next query (otherwise, stats will acummulate)
    MetaIndexManager.clearStats()
  }
}
