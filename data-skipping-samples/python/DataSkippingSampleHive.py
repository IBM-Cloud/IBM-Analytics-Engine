from pyspark.sql import SparkSession
from metaindex import MetaIndexManager

if __name__ == '__main__':
	spark = SparkSession\
        .builder\
        .appName("Data Skipping Hive Sample")\
        .enableHiveSupport()\
        .getOrCreate()

	# (optional) set log level to debug in metaindex to see skipping in the logs
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

	# inject the data skipping rule
	MetaIndexManager.injectDataSkippingRule(spark)

	# enable data skipping
	MetaIndexManager.enableFiltering(spark)

	# data set and metadata location
	dataset_location = "cos://mybucket.service/location/to/my/data"
	md_base_location = "cos://mybucket.service/location/to/my/base/metdata"

	# set the base metadata location in the database
	spark.sql("ALTER DATABASE default SET DBPROPERTIES ('spark.ibm.metaindex.parquet.mdlocation'='%s')" % md_base_location)

	# drop table if it already exists
	spark.sql("DROP TABLE IF EXISTS metergen")
	# create the table
	createTable = """CREATE EXTERNAL TABLE IF NOT EXISTS metergen (
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
          LOCATION '%s'
          TBLPROPERTIES ('parquet.compression'='SNAPPY' , 'transactional'='false')""" % dataset_location
	spark.sql(createTable)
	spark.sql("SHOW TABLES").show()

	# recovering the partitions
	spark.sql("ALTER TABLE metergen RECOVER PARTITIONS")

	# setup the JVM parameters for MetaIndexManager - In this example, we will set the base location to be retrieved
	# from the database properties
	# set Parquet as the default metadataStore
	MetaIndexManager.setDefaultMetaDataStore(spark, 'com.ibm.metaindex.metadata.metadatastore.parquet.Parquet')
	md_backend_config = dict([('spark.ibm.metaindex.parquet.mdlocation', "default"),
	 ("spark.ibm.metaindex.parquet.mdlocation.type", "HIVE_DB_NAME")])
	MetaIndexManager.setConf(spark, md_backend_config)

	# create MetaIndexManager instance with Parquet Metadatastore backend
	# and setting the table name in the MetaIndexManager properties so the metadata location
	# will be added automatically to the table properties
	md_backend = 'com.ibm.metaindex.metadata.metadatastore.parquet.ParquetMetadataBackend'
	im = MetaIndexManager(spark, "default.metergen", 'com.ibm.metaindex.metadata.metadatastore.parquet.ParquetMetadataBackend')
	im_config = dict([('spark.ibm.metaindex.parquet.mdlocation', "default.metergen"),
	 ("spark.ibm.metaindex.parquet.mdlocation.type", "HIVE_TABLE_NAME")])
	im.setMetadataStoreParameters(im_config)

	# view index status
	im.indexStats().show(10, False)

	# remove existing index first
	if im.isIndexed():
		im.removeIndex()

	# indexing
	print("Building the index:")
	im.indexBuilder().addMinMaxIndex("temp").addValueListIndex("city").addBloomFilterIndex("vid").build()

	# for refresh use
	# im.refreshIndex()

	# to view the index status use
	im.indexStats().show(10, False)

	# query the table and view skipping stats
	spark.sql("select count(*) from metergen where temp > 30").show()

	# get aggregated stats
	MetaIndexManager.getLatestQueryAggregatedStats(spark).show(10, False)

	# (optional) clear the stats for the next query (otherwise, stats will acummulate)
	MetaIndexManager.clearStats(spark)

	# stop SparkSession
	spark.stop()
