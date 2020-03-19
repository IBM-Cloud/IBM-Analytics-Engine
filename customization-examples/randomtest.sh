#!/usr/bin/bash
pip install xlwt
hdfs dfs -mkdir /user/clsadmin/mytest
hdfs dfs -put /home/common/lib/dataconnectorDb2/db2jcc4.jar /user/clsadmin/mytest/
sleep 3600
touch /home/wce/clsadmin/mgmt_node2
