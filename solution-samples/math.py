from pyspark.sql import SparkSession
import time
import random
import cmath
def init_spark():
  spark = SparkSession.builder.appName("shuffle-test").getOrCreate()
  sc = spark.sparkContext
  return spark,sc
def transformFunc(x):
  return cmath.sqrt(x)+cmath.log(x)+cmath.log10(x)
def main():
  spark,sc = init_spark()
  for i in range (0,1):
    data=range(100,100000000)
    partition=random.randint(3,5)
    v0 = sc.parallelize(data, partition)
    v1 = v0.map(transformFunc)
    print(f"v1.count is {v1.count()}. Done")
    time.sleep(30)
if __name__ == '__main__':
  main()
