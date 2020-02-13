import com.ibm.metaindex.metadata.metadatastore.parquet.{Parquet, ParquetMetadataBackend}
import com.ibm.metaindex.{MetaIndexManager, Registration}
import org.apache.log4j.{Level, LogManager, Logger}
import org.apache.spark.sql.SparkSession

/**
  * Sample of indexing and querying hive table using Parquet Metadatastore
  */
object MetaIndexManagerSample {
  val logger = Logger.getLogger(this.getClass)

  def main(args: Array[String]) {
    val spark = SparkSession
      .builder()
      .appName("MetaIndexManager Sample")
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

    // Setup the JVM parameters for MetaIndexManager and enable skipping
    MetaIndexManager.injectDataSkippingRule(spark)
    // set Parquet as the default metadataStore
    Registration.setDefaultMetaDataStore(Parquet)
    // Set the default metadata location to be a base path defined in the database
    val jvmParameters = new java.util.HashMap[String, String]()
    jvmParameters.put("spark.ibm.metaindex.parquet.mdlocation", md_base_path)
    jvmParameters.put("spark.ibm.metaindex.parquet.mdlocation.type", "EXPLICIT_BASE_PATH_LOCATION")
    MetaIndexManager.setConf(jvmParameters)
    // Enable data skipping
    MetaIndexManager.enableFiltering(spark)

    // index the dataset
    val im = new MetaIndexManager(spark, input_path, ParquetMetadataBackend)

    // remove existing index first
    if (im.isIndexed()) {
      im.removeIndex()
    }

    // Build the index
    println("Building the index:")
    val reader = spark.read.format("parquet")
    im.indexBuilder()
      .addMinMaxIndex("temp")
      .addValueListIndex("city")
      .addBloomFilterIndex("vid")
      .build(reader)

    // for refresh use
    //im.refreshIndex(reader)

    // to view the index status use
    im.getIndexStats().show()

    // Query the table and view skipping stats
    val df = reader.load(input_path)
    df.createOrReplaceTempView("metergen")
    spark.sql("select * from metergen where temp > 30").show()

    MetaIndexManager.getLatestQueryAggregatedStats(spark).show()
  }
}
