import org.apache.spark.SparkConf
import org.apache.spark.sql.SparkSession

object pmoanalysis 
{
  def main(args: Array[String]) 
  {

      val conf = new SparkConf()
      .setAppName("pmoanalysis")
      
      val spark = SparkSession
      .builder()
      .config(conf)
      .getOrCreate()

      val sc = spark.sparkContext
   
      val iamapikey =  args(0)     
      val endpoint  =  args(1)
      val projectfile = args(2)
     
      sc.hadoopConfiguration.set("fs.cos.prj.iam.api.key",iamapikey)
      sc.hadoopConfiguration.set("fs.cos.prj.endpoint", endpoint) 
      
      val sqlContext = new org.apache.spark.sql.SQLContext(sc)
      val projectDF = sqlContext.read.parquet(projectfile)
      projectDF.registerTempTable("projects")
      val billingRate = sqlContext.sql("select VENDORNAME,  ROUND(PROJECTCOST/EFFORT ,2)AS BILLINGRATE from projects ORDER BY BILLINGRATE")
      billingRate.show()
  }
}
