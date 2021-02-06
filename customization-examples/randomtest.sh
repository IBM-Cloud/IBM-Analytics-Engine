#!/usr/bin/bash
if [ "x$NODE_TYPE" == "management2" ]
then 
  /home/common/conda/miniconda3.7/bin/pip3 install xlwt
  hdfs dfs -mkdir /user/clsadmin/mytest
  hdfs dfs -put /home/common/lib/dataconnectorDb2/db2jcc4.jar /user/clsadmin/mytest/
  #sleep 120
  touch /home/wce/clsadmin/mgmt_node2
 fi
