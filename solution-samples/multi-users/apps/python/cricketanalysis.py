from pyspark.sql import SparkSession,SQLContext
import sys, time
from pyspark.sql.functions import desc
spark = SparkSession.builder.appName("cricket mania").getOrCreate()
hconf = spark.sparkContext._jsc.hadoopConfiguration()
hconf.set("fs.cos.sportywriter.access.key", sys.argv[1])
hconf.set("fs.cos.sportywriter.secret.key", sys.argv[2])
hconf.set("fs.cos.sportywriter.endpoint", sys.argv[3])
max_runs_df = spark.read.csv("cos://sportsbucket.sportywriter/cricket/maxruns-2019.csv", inferSchema = True, header = True)
max_runs_df.show()

# The following command prints the count of runs of each country in a descending order
country_group_df = max_runs_df.groupby("COUNTRY").count().sort(desc("count")).show()
country_group_df.show()

# The following code prints the count of MATCHES of each country in a descending order
sqlContext = SQLContext(spark.sparkContext)
max_runs_df.registerTempTable('maxruns2019')
sqlContext.sql('select COUNTRY, SUM(MATCHES) as TOTALMATCHES from maxruns2019 group by COUNTRY order by TOTALMATCHES DESC').show()

time.sleep(300)
