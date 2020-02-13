from pyspark.sql import SparkSession
from metaindex import MetaIndexManager

if __name__ == '__main__':
	#setup SparkSession
	spark = SparkSession\
        .builder\
        .appName("MetaIndexManager Sample")\
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
	hconf.set("fs.cos.service.endpoint" ,"https://s3.private.us.cloud-object-storage.appdomain.cloud")
	hconf.set("fs.cos.service.access.key", "<accessKey>")
	hconf.set("fs.cos.service.secret.key","<secretKey>")

	# dataset
	dataset_location = "cos://mybucket.service/location/to/my/data"
	# metadata base location
	md_base_location = "cos://mybucket.service/location/to/my/base/metdata"

	# Setup the JVM parameters for MetaIndexManager and enable skipping
	MetaIndexManager.injectDataSkippingRule(spark)
	# set Parquet as the default metadataStore
	MetaIndexManager.setDefaultMetaDataStore(spark, 'com.ibm.metaindex.metadata.metadatastore.parquet.Parquet')
	md_backend_config = dict([('spark.ibm.metaindex.parquet.mdlocation', md_base_location), ("spark.ibm.metaindex.parquet.mdlocation.type", "EXPLICIT_BASE_PATH_LOCATION")])
	MetaIndexManager.setConf(spark, md_backend_config)
	# Enable data skipping
	MetaIndexManager.enableFiltering(spark)

	# index the dataset
	im = MetaIndexManager(spark, dataset_location, 'com.ibm.metaindex.metadata.metadatastore.parquet.ParquetMetadataBackend')

	# remove existing index first
	if im.isIndexed():
		im.removeIndex()

	print("Building the index:")
	im.indexBuilder().addMinMaxIndex("temp").addValueListIndex("city").addBloomFilterIndex("vid").build(reader)

	# for refresh use
	#im.refreshIndex(reader)

	# to view the index status use
	im.indexStats().show()

	# Query the table and view skipping stats
	df = reader.load(dataset_location)
	df.createOrReplaceTempView("metergen")
	spark.sql("select count(*) from mtg where temp > 30").show()

	# get aggregated stats
	MetaIndexManager.getLatestQueryAggregatedStats(spark).show()

	# stop SparkSession
	spark.stop()
