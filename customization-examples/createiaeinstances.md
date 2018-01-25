# Create IAE instances from the command line

This tutorial is in two steps to help you understand and troubleshoot effectively. The first is to initiate and verify the creation of an uncustomized IAE instance. Then you will use an alternate configuration to create an instance with additional capabilities.

## Command summary

In summary, here are the commands that cover the full service lifecycle for our simple cluster

```
bx cf create-service IBMAnalyticsEngine lite iae-simple-cluster -c ./cluster-simple.json
bx cf service iae-simple-cluster
bx cf create-service-key iae-simple-cluster Credentials1 -c {}
bx cf service-key iae-simple-cluster Credentials1
bx cf delete-service-key iae-simple-cluster Credentials1 -f
bx cf delete-service iae-simple-cluster -f

```

## Create an uncustomized IAE instance

As part of instance creation you can include the cluster configuration parameters inline in the create command if you wish however to promote reusabiliy and consistency we are using the option to use a configuration file with the cluster configuration in it that could be reused across different creation scenarios. 

For the uncustomized IAE instance the configuration is [cluster-simple.json](cluster-simple.json) and just deploys a single spark compute node.

```
{
    "num_compute_nodes": 1,
    "hardware_config": "default",
    "software_package": "ae-1.0-spark"
}
```

If you wish to create a cluster with both Spark and Hadoop, you can switch to use [cluster-simple-spark-hadoop.json](cluster-simple-spark-hadoop.json) instead.

Assuming you have already performed [Preparing to use the IBM Cloud CLI](ibmcloudlogin.md) initiating creation a cluster is a single command `bx cf create-service IBMAnalyticsEngine ...`

There are three additional parameters for this command that can change depending on your needs.

1. Billing plan - The plan the cluster will use ( lite, standard-hourly or standard-monthly are the current options )
2. Cluster name - The name of the new cluster being created
3. Configuration - using option `-c` define which configuration file is being used for the service ( cluster-simple.json or cluster-custom.json in our case )

If we use the `lite` plan, name the cluster `iae-simple-cluster` and choose the configuration file `cluster-simple.json` the complete command would be

```
bx cf create-service IBMAnalyticsEngine lite iae-simple-cluster -c ./cluster-simple.json
```

Response:

```
Invoking 'cf create-service IBMAnalyticsEngine lite iae-simple-cluster -c ./cluster-simple.json'...

Creating service instance iae-simple-cluster in org jdoe123@us.ibm.com / space dev as jdoe123@us.ibm.com...
OK

Create in progress. Use 'cf services' or 'cf service iae-simple-cluster' to check operation status.
```

## Monitor instance creation progress

As mentioned in the command response, the cluster may take some time to initialize. If you use the provided command to check the status of your specific cluster the response will initially be similar to the following

```
bx cf service iae-simple-cluster
```
Initial response:-

```
Invoking 'cf service iae-simple-cluster'...


Service instance: iae-simple-cluster
Service: IBMAnalyticsEngine
Bound apps: 
Tags: 
Plan: lite
Description: Flexible framework to deploy Hadoop and Spark analytics applications.
Documentation url: https://console.bluemix.net/docs/services/AnalyticsEngine/index.html
Dashboard: https://ibmae-ui.mybluemix.net/analytics/engines/paygo/jumpout?apiKey=20171211234529437-UaoXMqSUzmMO&instanceId=f05e3da0-8f20-4466-aa59-f4068e4e38ab

Last Operation
Status: create in progress
Message: 
Started: 2017-12-11T23:45:45Z
Updated: 2017-12-11T23:48:00Z 
```

When complete the "Status" will change to "create succeeded"

```
...
Last Operation
Status: create succeeded
Message: 
...
```

## Interacting with the instance

You can now use the Dashboard URL in the previous command response to open the dashboard. e.g. 

```
https://ibmae-ui.mybluemix.net/analytics/engines/paygo/jumpout?apiKey=20171211234529437-UaoXMqSUzmMO&instanceId=f05e3da0-8f20-4466-aa59-f4068e4e38ab
```

From the dashboard you are able to get the username (clsadmin) and its password for your instance and launch the Ambari console to use those credentials if needed.

## Creating credentials for your cluster

To allow the use of the cluster by other clients and services of your choosing you will need the service credentials and URLs for your new instance. These can be created using the command `bx cf create-service-key ...` and retrieved using  `bx cf service-key iae-simple-cluster [key name]` to retrieve a specific key.


Create new credentails for the service usign this command. "Credentials1" is the name of your new credentials. You could use a name of your choosing. The `-c {}` is for optional parameters for the command which we have none.

```
bx cf create-service-key iae-simple-cluster Credentials1 -c {}
```

Response:

```
Invoking 'cf create-service-key iae-simple-cluster Credentials1 -c {}'...

Creating service key Credentials1 for service instance iae-simple-cluster as jdoe123@us.ibm.com...
OK

```

Retrieving the credentials by name is performed as follows. This gets you the username and password and all the endpoints for connecting to the cluster.

```
bx cf service-key iae-simple-cluster Credentials1
```

Response:

```
Invoking 'cf service-key iae-simple-cluster Credentials1'...

Getting key Credentials1 for service instance iae-simple-cluster as jdoe123@us.ibm.com...

{
 "cluster": {
  "cluster_id": "20171212-231742-501-LkJMPjVv",
  "password": "1Y0H4cvR3OeS",
  "service_endpoints": {
   "ambari_console": "https://chs-sqk-923-mn001.bi.services.us-south.bluemix.net:9443",
   "livy": "https://chs-sqk-923-mn001.bi.services.us-south.bluemix.net:8443/gateway/default/livy/v1/batches",
   "notebook_gateway": "https://chs-sqk-923-mn001.bi.services.us-south.bluemix.net:8443/gateway/default/jkg/",
   "notebook_gateway_websocket": "wss://chs-sqk-923-mn001.bi.services.us-south.bluemix.net:8443/gateway/default/jkgws/",
   "spark_history_server": "https://chs-sqk-923-mn001.bi.services.us-south.bluemix.net:8443/gateway/default/sparkhistory",
   "ssh": "ssh clsadmin@chs-sqk-923-mn003.bi.services.us-south.bluemix.net",
   "webhdfs": "https://chs-sqk-923-mn001.bi.services.us-south.bluemix.net:8443/gateway/default/webhdfs/v1/"
  },
  "service_endpoints_ip": {
   "ambari_console": "https://169.60.139.3:9443",
   "livy": "https://169.60.139.3:8443/gateway/default/livy/v1/batches",
   "notebook_gateway": "https://169.60.139.3:8443/gateway/default/jkg/",
   "notebook_gateway_websocket": "wss://169.60.139.3:8443/gateway/default/jkgws/",
   "spark_history_server": "https://169.60.139.3:8443/gateway/default/sparkhistory",
   "ssh": "ssh clsadmin@169.60.139.3",
   "webhdfs": "https://169.60.139.3:8443/gateway/default/webhdfs/v1/"
  },
  "user": "clsadmin"
 },
 "cluster_management": {
  "api_url": "https://api.dataplatform.ibm.com/v2/analytics_engines/44400588-e403-49b6-a666-6202032cd3cd",
  "instance_id": "44400588-e403-49b6-a666-6202032cd3cd"
 }
}
```

## Deleting the instance when done

If the purpose of the instance has a time limit, especically since billing is on the basis of node hours for the standard plan, it is useful to know how to delete the instance via the CLI too. 

If you created credentials in the previous section, you will need to delete them before you can delete the cluster itself. e.g.

```
bx cf delete-service-key iae-simple-cluster Credentials1 -f
```

The `-f` option turns off the need to confirm the deletion so you can script it without prompts.

Now you have cleaned up, the cluster deletion command is simple. 

```
bx cf delete-service iae-simple-cluster -f

Invoking 'cf delete-service iae-simple-cluster -f'...

Deleting service iae-simple-cluster in org jdoe123@us.ibm.com / space dev as jdoe123@us.ibm.com...
OK
```



