# Using a Compose MySQL instance for an IAE cluster Hive Metastore

The purpose of this customization is to create a new cluster and immediately after creation to change the HIVE Metastore configuration from using a local Derby database to connect to an IBM Cloud hosted Compose MySQL instance. Formal documentation for this topic can be found [here](https://console.bluemix.net/docs/services/AnalyticsEngine/working-with-hive.html#working-with-hive) 

This will be done using the [bootstrap-mysql.sh](bootstrap-mysql.sh) script included in this project together with the parameter file [cluster-custom-mysql.json](cluster-custom-mysql.json). 

## Command summary

For quick reuse, these are the commands required for the full lifecycle of our custom cluster. `bx cf create-service` is asynchronous but all other commands can be run without pauses. More background on using these commands can be found [here](createiaeinstances.md)

```
bx cf create-service IBMAnalyticsEngine standard-hourly iae-custom-cluster-mysql -c ./cluster-custom-mysql.json
bx cf service iae-custom-cluster-mysql
bx cf create-service-key iae-custom-cluster-mysql Credentials1 -c {}
bx cf service-key iae-custom-cluster-mysql Credentials1

bx cf delete-service-key iae-custom-cluster-mysql Credentials1 -f
bx cf delete-service iae-custom-cluster-mysql -f
```

## The details

### Cluster configuration file

The configuration we are using for the instance creation is [cluster-custom-mysql.json](cluster-custom-mysql.json) which includes a link to the [bootstrap-mysql.sh](bootstrap-mysql.sh) script. 

```
{
    "num_compute_nodes": 1,
    "hardware_config": "default",
    "software_package": "ae-1.0-hadoop-spark",
    "customization": [{
        "name": "action1",
        "type": "bootstrap",
        "script": {
            "source_type": "https",
            "source_props": {
                "username": "",
                "password": ""
            },
            "script_path": "https://raw.githubusercontent.com/shusseyIBM/iae-cli-create/master/bootstrap-mysql.sh"
        },
        "script_params": ["admin", "ZCBWXXXXXXMJET", "hive", "sl-us-south-1-portal.13.dblayer.com", "32023"]
    }]
}
```

To ensure that the bootstrap script does not need to be modified for each use, the MySQL database connection parameters are specified in the json `script_params` property here instead. This makes changes to the parameters simpler since the file is local to wherever you run the cluster creation command. It has the added benefit that credentials dont get stored in the URL addressable boostrap script file that could present security concerns.

The `script_params` property has 5 values. The bootstrap script will assign these properties to the following variables.

```
DB_USER_NAME=$1
DB_PWD=$2
DB_NAME=$3
DB_CXN_URL_HOST=$4
DB_CXN_URL_PORT=$5
```

These values are easy to discover from the IBM Cloud console for your MySQL instance. From the Manage view of Compose MySQL the first entry in the Connection Strings HTTPS secton gives you all the neccesary elements. For example: 

```
mysql://admin:ZCBWXXXXXXMJET@sl-us-south-1-portal.13.dblayer.com:32023/compose
```

becomes

```
"script_params": ["admin", "ZCBWXXXXXXMJET", "compose", "sl-us-south-1-portal.13.dblayer.com", "32023"]
```

You will notice, however that in the full example above, the third parameter is `hive` rather than `compose`. For MySQL this value is both the database name and schema name. MySQL uses the terms interchangeably.  

When you create a new Compose MySQL instance, the `compose` schema is created for you. You could have Hive use this schema to create its tables but it is a good practice to create a fresh schema in the instance for Hive use. You could also use one MySQL instance for more than one cluster but with different schema names to separate the data if you wish. In that case you would alter the schema name value for each unique cluster you create.

You do not need to do anything besides setting this value correctly to create each schema. The bootstrap script includes an option `?createDatabaseIfNotExist=true` that will take care of this for you.

So if you use this recommendation your parameters will look like this

```
"script_params": ["admin", "ZCBWXXXXXXMJET", "hive", "sl-us-south-1-portal.13.dblayer.com", "32023"]
```
### Boostrap script

To make the changes we need to the cluster after it has been created, we need enlist the help of Ambari.

Since all actions in the script go through Ambari, it is not critical which node of the cluster they run on but they should only run on one node not all of them. For our purposes we have selected them to run on "management-slave2" with the statement `if [ "x$NODE_TYPE" == "xmanagement-slave2" ]` . The simple reason for this is that, if you use the ssh url from the cluster credentials to connect, this is the node you connect to. Therefore the /var/log on this node will contain the bootstrap script log if you need to debug it.

#### The Ambari parameters

The first step in [bootstrap-mysql.sh](bootstrap-mysql.sh) is to change the neccesary HIVE parameters. The following parameters are set using /var/lib/ambari-server/resources/scripts/configs.sh and take the following form:

```
/var/lib/ambari-server/resources/scripts/configs.sh -u $AMBARI_USER -p $AMBARI_PASSWORD -port $AMBARI_PORT -s set $AMBARI_HOST  $CLUSTER_NAME hive-site "<Parameter name>" $DB_CXN_URL
```

These are the parameters the script changes from their defaults.

| Parameter | Value |
| --------- | ----- |
| javax.jdo.option.ConnectionUserName | The MySQL user name |
| javax.jdo.option.ConnectionPassword | The MySQL password |
| ambari.hive.db.schema.name | For MySQL schema name and database are synonymous |
| javax.jdo.option.ConnectionURL | The URL Hive uses to connect |

The ConnectionURL is constructed from the 5 script_params and will look similar to `jdbc:mysql://sl-us-south-1-portal.13.dblayer.com:32023/hive?createDatabaseIfNotExist=true`

#### The service restart

```
echo "******* Restart All Services"

echo "ambariStopAll begin:"
ambariStopAll

if [ $ambariStopAllStatus = "FAILED" ] 
    then
	    echo "Retry a second time due to a current bug that stalls Stop All in the Metrics Collector service"
	    ambariStopAll
   	 fi

echo "ambariStopAll final status = $ambariStopAllStatus"

echo "ambariStartAll begin:"
ambariStartAll
echo "ambariStartAll final status = $ambariStartAllStatus"
```

To ensure a clean restart and adoption of the changed configuration the script uses helper functions request service stops and starts and monitors progress before continuing. Although it may be possible to figure out which individual services need to be restarted in addition to HIVE and its sub components, it is more reliable to restart all Ambari controlled services. 

Starts and stop requests to Ambari are asynchronous so when one of these actions are requested, the response contains a request id. This id can then be used to query the ongoing status of the job until it completes or fails.

Note: At the time of publishing, an Ambari Stop All request will initially fail in the Metrics Collector service. The code currently will retry a second time for this reason.

The service stop usually occurs in less than a minute but the start will take 5 to 10 minutes to complete. If your cluster stays in the Customizing state a lot longer that this, you will have to connect to the slave2 node using the ssh string from the cluster credentials and look at the log file to diagnose. The file name is a combination of the host name of the node and the process number of the customization script. e.g.

```
/var/log/chs-pxv-079-mn003.bi.services.us-south.bluemix.net_12756.log
```

### Creating the cluster

Now we have the configuration file and the script it references we construct the `bx cf create-service IBMAnalyticsEngine ...` command

If we use the `standard-hourly` plan, name the cluster `iae-custom-cluster-mysql` and choose configuration `cluster-custom-mysql.json` the complete command would be :-

```
bx cf create-service IBMAnalyticsEngine standard-hourly iae-custom-cluster-mysql -c ./cluster-custom-mysql.json
```

## Did the customization work?

Monitor the creation of the cluster using `bx cf service iae-custom-cluster-mysql`. 

The bootstrap script is executed AFTER the cluster creation succeeds. So depending on your customization execution time, you may have to wait some additional time before you can use the cluster. 

The simplest way to monitor this second phase is using the IBM Cloud IAE Dashboard for your instance. The Dashboard will visaully show the status of "Customizing" while this is still pending. 

If you need to monitor progress via the command line, or if it doesnt move to an Active state in a reasonable amout of time, the steps to monitor and debug are provided in the [debugging](bootstrapscriptdebugging.md) page.

### Verifying Hive metastore customization worked

The simplest way to check if all is good is to log in to the Ambari console. Go to the IBM Cloud console to Manage your instance and launch Ambari. Once you connect you will see the health status of the cluster and any alerts requiring your attention. 

To use HIVE and through it, the HIVE Metastore, mouse over the 3x3 matrix icon in the top right of the page next to the clsadmin user name. Select either Hive View or Hive View 2.0 to excercise Hive.