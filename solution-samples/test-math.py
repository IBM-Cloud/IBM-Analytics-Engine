from pyspark.sql import SparkSession
import time
import random
import cmath
​
def init_spark():
  spark = SparkSession.builder.appName("test-math").getOrCreate()
  sc = spark.sparkContext
  return spark,sc
​
def transformFunc(x):
  return cmath.sqrt(x)+cmath.log(x)+cmath.log10(x)
​
def main():
  spark,sc = init_spark()
  partitions=[10,5,8,4,9,7,6,3]
  for i in range (0,8):
    data=range(1,20000000)
    v0 = sc.parallelize(data, partitions[i])
    v1 = v0.map(transformFunc)
    print(f"v1.count is {v1.count()}. Done")
    time.sleep(60)
  
if __name__ == '__main__':
  main()
