# IAE-Cluster-Management
IBM Cloud's spark cluster offering [Analytics Engine (IAE)](https://www.ibm.com/cloud/analytics-engine) exposes [REST APIs](https://cloud.ibm.com/docs/services/AnalyticsEngine?topic=AnalyticsEngine-IAE-overview) to manage the clusters. These APIs provides flexibity in provisioning, customization, job submission and deletion of the clusters using scripts instead of performing these actions manually through Bluemix console.

 The python utility functions provided here makes it easier to call these APIs. These utility functions can be called in sequence to create a pipeline of jobs which creates a cluster on the fly, run a job and delete the cluster. This helps in keeping costs under control as clusters exist only for the duration of the job instead and there is no idle time charges being incurred.
 
## Scenarios and Benefits of scripted cluster management
 * IBM Cloud team regularly releases updates to IAE. The script can be used to delete old clusters and create new on a weekly or monthly basis to take advantage of new features and bug fixes.
 * Scripts allows scheduling of cluster creation and deletion using cron jobs, jenkins, etc
 * Keeps cost of IAE to minimum as the cluster get created only when needed. No idle time.
 * Clusters with different specficitions can be created for different application. Small standard cluster for low resource requirement jobs and big memory intensive clusters for high resource requirement jobs.
 * Allows to create job pipelines which provides consistency in cluster configuration between different cycles
 
## Files
* **manage_iae_cluster_utils.py** - Contains all the utility functions which makes the REST API calls to IBM Cloud platform.   
      __Main functions__
      
      * run_cluster_provision(): Starts cluster provisioning with specifed configuration parameters 
      and wait for the provisioning to be complete.
      
      * get_cluster_credentials(): Returns the credentials as json object which could be saved to a file. 
      Note that new IAE clusters no longer stores the password in service credentials json in bluemix console. 
      The password is needed to login into amabari, spark history server and unix machines.
      
      * run_cluster_customization(): This function takes any adhoc provided as github file and runs them on all 
      nodes in the cluster. It can be used to download jars, install packages or customize environment variables.
      
      * run_spark_job_to_completion(): Takes a job config json file and submits it to the specified cluster 
      and waits for it to complete.
      
      * run_cluster_deletion(): Deletes the specified cluster
          
* **sample_job_pipeline.py** - Sample pipeline created using the utility functions. It creates a new cluster, customizes it, runs a spark application and deletes the cluster after job is complete.

* **sample_app_config.json** - JSON file which is used to provide parameters for spark application submission. The list of parameters allowed and their definitions can be found at [Livy POST /batches](https://github.com/cloudera/livy#post-batches)


### Input parameters required for functions:

* region :  default= 'us-south', Possible values { us-south, eu-gb, jp-tok or eu-de }. The region is important becuase it decides the API URLs.
* bmx_api_key : Bluemix platform key https://cloud.ibm.com/iam/apikeys            
* iae_name : Name of the IAE cluster 
* resource_group_name : Bluemix resource group to which this new cluster would be associated
* compute_node_count : Range 1-20, the number nodes required in the cluster
* hardware_config : choose from {default , memory-intensive}
* iae_plan :  chosose from {lite, hourly , monthly}
* git_token : github access tokens. can be obtain from https://github.ibm.com/settings/tokens
* git_org : Github org name where customization script is stored
* git_user : Github user name to access script
* git_script_path : Complete url of the raw script file e.g. https://raw.github.ibm.com/WCP-Consumption-Tech/wcpct-datascience/master/pylib/fixIAE.sh
* script_params : list of space separated parameters for script, if any
* app_config_path : location of the json file which contains spark submit parameters

_NOTE : REST APIs and endpoints change with new releases of IAE and platform services, so the utility scripts would need to be updated accordingly in future._ 
