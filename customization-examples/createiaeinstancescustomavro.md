# Create a custom IAE instance with Avro

The customization that we are applying in this example is to add [Avro](https://github.com/databricks/spark-avro) to our Spark cluster. 

This will be done using a [bootstrap-avro.sh](bootstrap-avro.sh) script included in this project together with the parameter file [cluster-custom-avro.json](cluster-custom-avro.json). 

## Command summary

For quick reuse, these are the commands required for the full lifecycle of our custom cluster. `bx cf create-service` is asynchronous but all other commands can be run without pauses. More background on using these commands can be found [here](createiaeinstances.md)

```
bx cf create-service IBMAnalyticsEngine standard-hourly iae-custom-cluster-avro -c ./cluster-custom-avro.json
bx cf service iae-custom-cluster-avro
bx cf create-service-key iae-custom-cluster-avro Credentials1 -c {}
bx cf service-key iae-custom-cluster-avro Credentials1

bx cf delete-service-key iae-custom-cluster-avro Credentials1 -f
bx cf delete-service iae-custom-cluster-avro -f
```

## The details

### Cluster configuration file

The configuration we are using for the custom instance creation is [cluster-custom-avro.json](cluster-custom-avro.json) which includes a link to a custom bootstrap-avro.sh script. 

```
{
    "num_compute_nodes": 1,
    "hardware_config": "default",
    "software_package": "ae-1.0-spark",
    "customization": [{
        "name": "action1",
        "type": "bootstrap",
        "script": {
            "source_type": "https",
            "source_props": {
                "username": "",
                "password": ""
            },
            "script_path": "https://raw.githubusercontent.com/shusseyIBM/iae-cli-create/master/bootstrap-avro.sh"
        },
        "script_params": []
    }]
}
```

Notice `script_path` points to a web location ( In the default case, to a file in this git project ). The script must be in a location the cluster nodes can access themselves as they start because the [bootstrap-avro.sh](bootstrap-avro.sh) script is executed on all nodes. You cannot store this file on your local machine. There are multiple options for where it can be stored described in the documentation section titled [Location of the customization script](https://console.bluemix.net/docs/services/AnalyticsEngine/customizing-cluster.html#customizing-a-cluster)

### Boostrap script

If you take a look at the logic of [bootstrap-avro.sh](bootstrap-avro.sh) there are two parts to it. The first is the installation of the Avro package. We download and unpack [Apache Ivy](http://ant.apache.org/ivy/) which is a dependency manager. We create a configuration file for it and then run it to install Avro and all its dependencies. This part of the script will run on all nodes and will also run on new nodes if you add them after initial cluster creation.

The second part of the script only runs on the management_slave2 node and instructs Ambari to perform services stop and start commands. This ensures that the cluster adopts the new module correctly. It will, however, extend the cluster initialization time given that there are a couple of `sleep` commands to allow the restart to complete. 

## Creating the cluster

Now we have the configuration file and the script it references we construct the `bx cf create-service IBMAnalyticsEngine ...` command

If we use the `standard-hourly` plan, name the cluster `iae-custom-cluster-avro` and choose configuration `cluster-custom-avro.json` the complete command would be :-

```
bx cf create-service IBMAnalyticsEngine standard-hourly iae-custom-cluster-avro -c ./cluster-custom-avro.json
```

If you do not have access to an account that can be billed for services, you can revert to 'lite' for the plan.

## Did the customization work?

Monitor the creation of the cluster using `bx cf service iae-custom-cluster-avro`. 

The bootstrap script is executed AFTER the cluster creation succeeds. So depending on your customization execution time, you may have to wait some additional time before you can use the cluster. 

The simplest way to monitor this second phase is using the IBM Cloud IAE Dashboard for your instance. The Dashboard will visaully show the status of "Customizing" while this is still pending. 

If you need to monitor progress via the command line, or if it doesnt move to an Active state in a reasonable amout of time, the steps to monitor and debug are provided in the [debugging](bootstrapscriptdebugging.md) page.




## Using the custom IAE cluster from a local Jupyter instance

Finally, the real test for our purposes is to try the new functionality. 

Make sure your cluster is finished creating and customizing. Use the `bx cf create-service-key ...` command to create the credentials and then `bx cf service-key ...` to retrieve them. 

```
bx cf create-service-key iae-custom-cluster-avro Credentials1 -c {}
bx cf service-key iae-custom-cluster-avro Credentials1
```

Copy the portion response to `bx cf service-key ...` starting and ending with `{ ... }` and replace the contents of `vcap.json` in this project.

Now, if you have Docker installed on your client, use the `./run_docker_notebook.sh` command to initialize a Jupyter instance on your workstation. It will read the file you just updated and connect the instance to your customized cluster in the IBM Cloud. 

Copy the localhost URL and launch it in a browser. You will find a notebook `avro_test` already loaded. Open that notebook and select `Cell->Run All` . If the result is as follows, you know that Avro was used to retrieve the data

```
+----------+--------------------+----------+
|  username|               tweet| timestamp|
+----------+--------------------+----------+
|    miguno|Rock: Nerf paper,...|1366150681|
|BlizzardCS|Works as intended...|1366154481|
+----------+--------------------+----------+
```

