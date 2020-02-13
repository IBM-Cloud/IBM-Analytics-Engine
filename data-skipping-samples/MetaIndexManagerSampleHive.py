from pyspark.sql import SparkSession
from metaindex import MetaIndexManager

if __name__ == '__main__':
	#setup SparkSession
	spark = SparkSession\
        .builder\
        .appName("MetaIndexManager Hive Sample")\
        .enableHiveSupport()\
        .getOrCreate()

	# (optional) set log level to debug in metaindex to see skipping in the logs
	log4jLogger = spark.sparkContext._jvm.org.apache.log4j
	log4jLogger.LogManager.getLogger('com.ibm.metaindex.search').setLevel(log4jLogger.Level.DEBUG)

	# setup the environment
	hconf = spark.sparkContext._jsc.hadoopConfiguration()
	# configure Stocator
    hconf.set("fs.stocator.scheme.list", "cos")
    hconf.set("fs.cos.impl", "com.ibm.stocator.fs.ObjectStoreFileSystem")
    hconf.set("fs.stocator.cos.impl", "com.ibm.stocator.fs.cos.COSAPIClient")
    hconf.set("fs.stocator.cos.scheme", "cos")

    # for more info on how to config credentials see https://github.com/CODAIT/stocator
    # see https://cloud.ibm.com/docs/services/cloud-object-storage?topic=cloud-object-storage-endpoints for the list of endpoints
    hconf.set("fs.cos.service.endpoint" ,"http://s3.us-south.objectstorage.softlayer.net")
    hconf.set("fs.cos.$serviceName.access.key", "<accessKey>")
    hconf.set("fs.cos.service.secret.key","<secretKey>")

	# dataset
	dataset_location = "cos://mybucket.service/location/to/my/data"
	# metadata base location
	md_base_location = "cos://mybucket.service/location/to/my/base/metdata"

	# set the base metadata location in the database
	spark.sql("ALTER DATABASE default SET DBPROPERTIES ('spark.ibm.metaindex.parquet.mdlocation'='%s')" % md_base_location)

	# drop table if it already exists
	spark.sql("DROP TABLE IF EXISTS metergen")
	# create hive metastore table
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

	# Recovering the partitions
	spark.sql("ALTER TABLE metergen RECOVER PARTITIONS")

	# Setup the JVM parameters for MetaIndexManager and enable skipping
	MetaIndexManager.injectDataSkippingRule(spark)
	# set Parquet as the default metadataStore
	MetaIndexManager.setDefaultMetaDataStore(spark, 'com.ibm.metaindex.metadata.metadatastore.parquet.Parquet')
	md_backend_config = dict([('spark.ibm.metaindex.parquet.mdlocation', md_base_location), ("spark.ibm.metaindex.parquet.mdlocation.type", "HIVE_DB_NAME")])
	MetaIndexManager.setConf(spark, md_backend_config)
	# Enable data skipping
	MetaIndexManager.enableFiltering(spark)

	# index the dataset - using the table name
	im = MetaIndexManager(spark, "default.metergen", 'com.ibm.metaindex.metadata.metadatastore.parquet.ParquetMetadataBackend')
	im_config = dict([('spark.ibm.metaindex.parquet.mdlocation', "default.metergen"), ("spark.ibm.metaindex.parquet.mdlocation.type", "HIVE_TABLE_NAME")])
	im.setMetadataStoreParameters(spark, im_config)

	# remove existing index first
	if im.isIndexed():
		im.removeIndex()

	# indexing
	print("Building the index:")
	im.indexBuilder().addMinMaxIndex("temp").addValueListIndex("city").addBloomFilterIndex("vid").build()

	# for refresh use
	#im.refreshIndex()

	# to view the index status use
	im.indexStats().show()

	# Query the table and view skipping stats
	spark.sql("select count(*) from mtg where temp > 30").show()

	# get aggregated stats
	MetaIndexManager.getLatestQueryAggregatedStats(spark).show()

	# stop SparkSession
	spark.stop()
