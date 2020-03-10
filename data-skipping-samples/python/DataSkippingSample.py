from pyspark.sql import SparkSession
from metaindex import MetaIndexManager

if __name__ == '__main__':
	spark = SparkSession\
        .builder\
        .appName("Data Skipping Sample")\
        .getOrCreate()

	# (optional) set log level to debug specifically for metaindex package - to view the skipped objects
	log4jLogger = spark.sparkContext._jvm.org.apache.log4j
	log4jLogger.LogManager.getLogger('com.ibm.metaindex.search').setLevel(log4jLogger.Level.DEBUG)

	# setup the environment
	hconf = spark.sparkContext._jsc.hadoopConfiguration()
	# configure Stocator
	# for more info on how to config credentials see https://github.com/CODAIT/stocator
	# see https://cloud.ibm.com/docs/services/cloud-object-storage?topic=cloud-object-storage-endpoints for the list of endpoints
	# make sure you choose the private endpoint of your bucket
	hconf.set("fs.cos.service.endpoint" ,"https://s3.private.us-south.cloud-object-storage.appdomain.cloud")
	hconf.set("fs.cos.service.access.key", "<accessKey>")
	hconf.set("fs.cos.service.secret.key","<secretKey>")

	# data set and metadata location
	dataset_location = "cos://mybucket.service/location/to/my/data"
	md_base_location = "cos://mybucket.service/location/to/my/base/metdata"

	# setup the JVM parameters for MetaIndexManager - In this example, we will set the JVM wide parameter to a
	# base path to store all of the indexes.

	# set Parquet as the default metadataStore
	MetaIndexManager.setDefaultMetaDataStore(spark, 'com.ibm.metaindex.metadata.metadatastore.parquet.Parquet')
	md_backend_config = dict([('spark.ibm.metaindex.parquet.mdlocation', md_base_location),
	 ("spark.ibm.metaindex.parquet.mdlocation.type", "EXPLICIT_BASE_PATH_LOCATION")])
	MetaIndexManager.setConf(spark, md_backend_config)

	# create MetaIndexManager instance with Parquet Metadatastore backend
	md_backend = 'com.ibm.metaindex.metadata.metadatastore.parquet.ParquetMetadataBackend'
	reader = spark.read.format("parquet")
	im = MetaIndexManager(spark, dataset_location, md_backend)

	# remove existing index first
	if im.isIndexed():
		im.removeIndex()

	# indexing
	print("Building the index:")
	im.indexBuilder().addMinMaxIndex("temp").addValueListIndex("city").addBloomFilterIndex("vid").build(reader).show(10, False)

	# for refresh use
	# im.refreshIndex(reader).show(10, False)

	# view index status
	im.indexStats().show(10, False)

	# inject the data skipping rule
	MetaIndexManager.injectDataSkippingRule(spark)

	# enable data skipping
	MetaIndexManager.enableFiltering(spark)

	# query the table and view skipping stats
	df = reader.load(dataset_location)
	df.createOrReplaceTempView("metergen")
	spark.sql("select count(*) from metergen where temp > 30").show()

	# get aggregated stats
	MetaIndexManager.getLatestQueryAggregatedStats(spark).show(10, False)

	# (optional) clear the stats for the next query (otherwise, stats will acummulate)
	MetaIndexManager.clearStats(spark)

	# stop SparkSession
	spark.stop()
