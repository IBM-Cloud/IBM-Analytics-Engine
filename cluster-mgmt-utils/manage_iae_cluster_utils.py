import sys,requests,json,time,os,argparse,re
from retrying import retry
from datetime import datetime

# Set constants and the region which defines the REST API paths to use
def init(REGION = 'us-south'):  
    IAM_PATHS = {"us-south":"https://iam.ng.bluemix.net/identity/token", 
                 "eu-gb": "https://api.eu-gb.bluemix.net/identity/token", 
                 "jp-tok" : "https://iam.ng.bluemix.net/identity/token", 
                 "eu-de": "https://api.eu-de.bluemix.net/identity/token"
                }

    if REGION not in IAM_PATHS:
        raise Exception("Incorrect region_id provided:{} Valid region_ids:".format(REGION, list(IAM_PATHS.keys())))
    
    globals()['IAM_AUTH_PATH'] = IAM_PATHS[REGION]
    globals()['IAE_API_PATH'] = 'https://api.{}.ae.cloud.ibm.com/v2/analytics_engines'.format(REGION)
    globals()['RESOURCE_CONTROLLER_PATH_V1'] = 'https://resource-controller.cloud.ibm.com/v1'
    globals()['RESOURCE_CONTROLLER_PATH_V2'] = 'https://resource-controller.bluemix.net/v2' 
    globals()['WDP_API_PATH'] = 'https://api.dataplatform.cloud.ibm.com/v2'
    globals()['IAE_RESOURCE_PLANS'] = {'lite': '7715aa8d-fb59-42e8-951e-5f1103d8285e',
                                       'hourly':'3175a5cf-61e3-4e79-aa2a-dff9a4e1f0ae',
                                       'monthly':'34594484-afda-40e6-b93b-341fbbaed242'}
    globals()['HARDWARE_CONFIGS'] = ['default','memory-intensive']

    globals()['CLUSTER_PROVISION_TEMPLATE']={
        "name": "<IAE_NAME>",
        "resource_plan_id": "<RESOURCE_PLAN_ID>", 
        "resource_group_id": "<RESOURCE_GROUP_ID>",
        "region_id": REGION,
        "parameters": {
            "hardware_config": "<HARDWARE_CONFIG>",
            "num_compute_nodes": "<COMPUTE_NODE_COUNT>",
            "software_package": "ae-1.1-hadoop-spark", 
                 #ae-1.2-hive-llap, ae-1.2-hive-spark, ae-1.2-hadoop-spark,ae-1.1-spark, ae-1.1-hive-spark, ae-1.1-hadoop-spark
            "advanced_options": {
                  "ambari_config": {
                        "spark2-defaults": {
                                "spark.dynamicAllocation.enabled": True,
                                "spark.shuffle.service.enabled": True,
                                "spark.dynamicAllocation.minExecutors": "1" ,
                                "spark.dynamicAllocation.maxExecutors": "10",
                                "spark.dynamicAllocation.cachedExecutorIdleTimeout": "900",
                                "spark.dynamicAllocation.executorIdleTimeout": "300",
                                "spark.executor.instances" : "1",
                                "spark.executor.cores": "1",
                                "spark.executor.memory": "4G",
                                "spark.driver.cores": "1",
                                "spark.driver.memory": "4G",
                                "spark.python.profile": False
                        }
                 }
           }
        }
    }
     
    globals()['CLUSTER_CUSTOMIZATION_TEMPLATE'] ={
        "target": "all",
        "custom_actions": [{
                                "name":"install_customization",
                                "script":{
                                          "source_type": "https",
                                          "source_props": {
                                                  "base_url":"https://github.ibm.com/api/v3",
                                                  "org": "<GIT_ORG>",
                                                  "token": "<GIT_TOKEN>",
                                                  "user":"<GIT_USER>"
                                           },
                                           "script_path": "<GIT_SCRIPT_PATH>"
                                 },
                                 "script_params": ["<SCRIPT_PARAMS>"]
                             }]
        }
    
    return

def printLog(*msgs):    
    print(datetime.now().strftime("%Y-%m-%d %H:%M:%S") , ' '.join(map(str, msgs)) )

@retry(stop_max_attempt_number=5, wait_fixed=60000)
def get_iam_token(api_key):
    printLog("Get IAM Auth token")
    headers = {"Content-type": "application/x-www-form-urlencoded","Authorization": "Basic Yng6Yng="}
    data = "apikey={}&grant_type=urn%3Aibm%3Aparams%3Aoauth%3Agrant-type%3Aapikey".format(api_key)
    response=requests.post(IAM_AUTH_PATH, headers=headers, data=data)
    iam_token=response.json()['access_token']
    return iam_token

@retry(stop_max_attempt_number=5, wait_fixed=60000)
def get_iae_instance_id(name, iam_token):
    printLog("Get instance id for", name)
    headers = {"Authorization": "Bearer {}".format(iam_token)}
    url = "{}/resource_instances".format(RESOURCE_CONTROLLER_PATH_V1)
    response=requests.get(url, headers=headers)
    resources=response.json()['resources']
    instance_id=None
    for resource in resources:
        if resource['name'] == name:
            instance_id=resource['guid']
            break
    return instance_id

@retry(stop_max_attempt_number=5, wait_fixed=60000)
def get_resource_group_id(api_key, group_name):
    printLog("Get resource group id for", group_name)
    iam_token = get_iam_token(api_key)
    headers = {"Authorization": "Bearer {}".format(iam_token)}
    url = "{}/resource_groups".format(RESOURCE_CONTROLLER_PATH_V1)
    response=requests.get(url, headers=headers)
    resources=response.json()['resources']
    resource_group_id=None
    for resource in resources:
        if resource['name'] == group_name:
            resource_group_id=resource['id']
            break
    return resource_group_id

# gets the named project attributes and clusters with its credentials (including IAE passwords)
# Currently, only way to get IAE password without changing it.
# https://ibm-cloudplatform.slack.com/archives/C7DGE3CUV/p1559059138002600
@retry(stop_max_attempt_number=5, wait_fixed=60000)
def get_studio_project_config(api_key, project_name):
    printLog("Get studio project config for", project_name)
    iam_token=get_iam_token(api_key)
    headers = {"Authorization": "Bearer {}".format(iam_token),"Content-Type": "application/json"}    
    url="{}/projects?name={}".format(WDP_API_PATH, project_name)
    response=requests.get(url, headers=headers)
    return response.json()
   
@retry(stop_max_attempt_number=5, wait_fixed=60000)    
def get_customization_status(instance_id, request_id, iam_token):
    headers = {"Authorization": "Bearer {}".format(iam_token),"Content-Type": "application/json"}
    url="{}/{}/customization_requests/{}".format(IAE_API_PATH, instance_id,request_id)
    response=requests.get(url, headers=headers)
    #printLog(response.text)
    return response.json()

def wait_for_customization_completion(instance_id, request_id, iam_token, wait_interval_sec=60):
    run_status='CustomizingCluster'
    printLog("Waiting for cluster customization to finish ..")
    while run_status == 'CustomizingCluster':
        time.sleep(wait_interval_sec)
        response=get_customization_status(instance_id, request_id, iam_token)
        run_status=response['run_status']        
    if run_status == 'Failed':
        printLog("Error customizing cluster.")
        raise Exception(response.text)
    printLog("Customization complete with status=",run_status)
    return

# Run a adhoc script downloaded from github to customize all the nodes in the cluster 
# https://cloud.ibm.com/docs/AnalyticsEngine?topic=AnalyticsEngine-cust-cluster&locale=en
def run_cluster_customization(bmx_api_key,  iae_name, git_token, git_org, git_user, git_script_path, script_params):
    printLog("Start cluster customization for",iae_name)
    iam_token=get_iam_token(bmx_api_key)
    instance_id=get_iae_instance_id(iae_name, iam_token)
    headers = {"Authorization": "Bearer {}".format(iam_token),"Content-Type": "application/json"}
    url="{}/{}/customization_requests".format(IAE_API_PATH, instance_id)
    template=CLUSTER_CUSTOMIZATION_TEMPLATE
    template["custom_actions"][0]["script_params"]=script_params.split()
    
    # add git token to the url
    if git_script_path.startswith("https://"):
        git_script_path = git_script_path.replace("https://", "https://{}@".format(git_token))
    else:
        git_script_path = "{}@{}".format(git_token, git_script_path)
        
    data = json.dumps(template)\
                .replace("<GIT_TOKEN>",git_token)\
                .replace("<GIT_SCRIPT_PATH>",git_script_path)\
                .replace("<GIT_ORG>",git_org)\
                .replace("<GIT_USER>",git_user)
                                
    #printLog(url, headers, data)
    response=requests.post(url, headers=headers, data=data)
    printLog(response.text)    
    if hasattr(response, 'json') and 'request_id' in response.json():
        request_id=response.json()['request_id']
        wait_for_customization_completion(instance_id, request_id, iam_token)
    else:
        printLog("Error customizing cluster.")
        printLog(response.text)
        raise Exception(response.text)
    printLog("Cluster customization done.")
    return


@retry(stop_max_attempt_number=5, wait_fixed=60000)
def get_provision_status(instance_id, iam_token):
    headers = {"Authorization": "Bearer {}".format(iam_token),"Content-Type": "application/json"}
    url = "{}/{}/state".format(IAE_API_PATH, instance_id)
    response = requests.get(url, headers=headers)
    return response.json()

# monitor and wait for povisioning to complete. Sleep 1min between status checks
def wait_for_provision_completion(instance_id, iam_token, wait_interval_sec=60):
    run_status='Preparing'
    printLog("Waiting for provisioning to complete...")
    while run_status in ['Preparing','Inactive']:
        time.sleep(wait_interval_sec)
        response = get_provision_status(instance_id, iam_token)
        run_status = response['state']
        #printLog(response)
    if run_status == 'Failed':
        printLog("Error creating cluster.")
        raise Exception(response.text)
        
    printLog("Provisioning complete with status=", run_status)
    return

#Start the provisioning and wait for it to complete
# https://cloud.ibm.com/docs/AnalyticsEngine?topic=AnalyticsEngine-provisioning-IAE&locale=en
def run_cluster_provision(bmx_api_key, iae_name, resource_group_name, compute_node_count, hardware_config, iae_plan):
    printLog("Start cluster provisioning", iae_name)
    if hardware_config not in HARDWARE_CONFIGS:
        raise Exception("Incorrect IAE hardware_config provided:{} .. Correct values{}".format(hardware_config, HARDWARE_CONFIGS))
    if iae_plan not in IAE_RESOURCE_PLANS:
        raise Exception("Incorrect IAE iae_plan provided:{} .. Correct values{}".format(iae_plan, list(IAE_RESOURCE_PLANS.keys())))
    
    resource_group_id = get_resource_group_id(bmx_api_key, resource_group_name)
    iam_token = get_iam_token(bmx_api_key)
    
    headers = {"Authorization": "Bearer {}".format(iam_token),"Content-Type": "application/json"}
    cluster_config = CLUSTER_PROVISION_TEMPLATE
    cluster_config['name'] = iae_name
    cluster_config['resource_plan_id'] = IAE_RESOURCE_PLANS[iae_plan]
    cluster_config['resource_group_id'] = resource_group_id
    cluster_config['parameters']['num_compute_nodes'] = compute_node_count
    cluster_config['parameters']['hardware_config'] = hardware_config
    data = json.dumps(cluster_config)
    #printLog(url, headers, data)
    url="{}/resource_instances".format(RESOURCE_CONTROLLER_PATH_V1)
    response=requests.post(url, headers=headers, data=data)
    printLog("Cluster provisioning started... ")
    # if provisioning started, wait for completion
    if hasattr(response, 'json') and 'guid' in response.json():
        instance_id=response.json()['guid']
        wait_for_provision_completion(instance_id, iam_token)
    else:
        printLog("Error creating cluster.")
        printLog(response.text)
        raise Exception(response.text)
    return

#https://cloud.ibm.com/apidocs/resource-controller#delete-a-resource-key-by-id
def run_cluster_resource_keys_deletion(api_key, iae_name):
    printLog("Delete resource keys for ", iae_name)
    iam_token=get_iam_token(api_key)
    instance_id=get_iae_instance_id(iae_name, iam_token)
    if not instance_id:
        raise Exception("Cluster deletion failed. No such cluster.")
    headers = {"Authorization": "Bearer {}".format(iam_token),"Content-Type": "application/json"}
    url="{}/resource_instances/{}/resource_keys".format(RESOURCE_CONTROLLER_PATH_V2, instance_id)
    response=requests.get(url, headers=headers).json()
    for resource in response['resources']:
        key = resource['guid']        
        url="{}/resource_keys/{}".format(RESOURCE_CONTROLLER_PATH_V2, key)
        requests.delete(url, headers=headers)
    return

# https://cloud.ibm.com/docs/services/AnalyticsEngine?topic=AnalyticsEngine-delete-service#resource-controller-rest-api
@retry(stop_max_attempt_number=5, wait_fixed=60000)
def run_cluster_deletion(bmx_api_key, iae_name):
    run_cluster_resource_keys_deletion(bmx_api_key, iae_name) # New IAE, delete resource keys first
    printLog("Delete cluster", iae_name)
    iam_token=get_iam_token(bmx_api_key)
    instance_id=get_iae_instance_id(iae_name, iam_token)
    if not instance_id:
        raise Exception("Cluster deletion failed. No such cluster.")
    headers = {"Authorization": "Bearer {}".format(iam_token),"Content-Type": "application/json"}
    url="{}/resource_instances/{}".format(RESOURCE_CONTROLLER_PATH_V2, instance_id)
    requests.delete(url, headers=headers)
    return

# https://ibm-cloudplatform.slack.com/archives/C7DGE3CUV/p1559059138002600
# https://www.ibm.com/blogs/bluemix/2019/02/ibm-analytics-engine-changes-to-cluster-credential-access/
# New IAE clusters no longer store passwords. Reset Password API shud be called at cluster creation to
# get the password and shud be stored for downstream API calls. 
# This is only way to get passwords unless the cluster has already been 
# added to Watson Studio, in which case, use get_studio_project_config() to get password.
@retry(stop_max_attempt_number=15, wait_fixed=60000)
def get_cluster_credentials(api_key, iae_name):
    printLog("Get cluster credentials for", iae_name)
    iam_token=get_iam_token(api_key)
    instance_id = get_iae_instance_id(iae_name, iam_token)
    if not instance_id:
        raise Exception("Unable to obtain cluster instance id.")
        
    iae_credentials = {}
    
    # Get username/password
    headers = {"Authorization": "Bearer {}".format(iam_token),"Content-Type": "application/json"}
    url="{}/{}/reset_password".format(IAE_API_PATH, instance_id)
    response=requests.post(url, headers=headers)    
    if hasattr(response, 'json'):
        credentials=response.json()['user_credentials']            
        iae_credentials['username']=credentials['user']
        iae_credentials['password']=credentials['password']
    else:
        printLog("Unable to retrieve user/password.")
        printLog(response.text)
        raise Exception('Unable to retrieve user/password')

    # Recent change in REST API for new IAE Cluster. First get source_crn for IAE, to get endpoints!!!
    headers = {"Authorization": "Bearer {}".format(iam_token),"Content-Type": "application/json"}
    url = '{}/resource_instances'.format(RESOURCE_CONTROLLER_PATH_V2)
    response=requests.get(url, headers=headers)
    source_crn = None
    for resource in response.json()['resources']:
        if resource['name'] == iae_name:
            source_crn = resource['crn']
    
    # Get service endpoints using the source crn
    headers = {"Authorization": "Bearer {}".format(iam_token),"Content-Type": "application/json"}
    data = {'name': iae_name, 'source_crn':source_crn}
    url = '{}/resource_keys'.format(RESOURCE_CONTROLLER_PATH_V1)
    response = requests.post(url, headers=headers, data= json.dumps(data))
    response = json.loads(re.sub('mn00.', 'mn003', response.text))# sometimes credentials return host with "mn001" which is never reachable
    if 'credentials' in response:
        iae_credentials['service_endpoints']= response['credentials']['cluster']['service_endpoints']
    else:
        printLog("Error getting cluster service credentials.")
        printLog(response)
        raise Exception(response)
    
    return iae_credentials


@retry(stop_max_attempt_number=5, wait_fixed=60000)
def get_spark_job_status(credentials, job_id):
        headers = {'Content-Type': 'application/json', 'X-Requested-By': 'livy'}
        url = "{}/{}/state".format(credentials['service_endpoints']['livy'], job_id)
        response = requests.get(url, headers=headers, auth=(credentials['username'], credentials['password']))
        printLog("job state:", response.text)
        return response.json()['state']

@retry(stop_max_attempt_number=5, wait_fixed=60000)
def get_spark_job_log(credentials, job_id):
        headers = {'Content-Type': 'application/json', 'X-Requested-By': 'livy'}
        url = "{}/{}/log".format(credentials['service_endpoints']['livy'], job_id)
        response = requests.get(url, headers=headers, auth=(credentials['username'], credentials['password']))
        return response.json()['log']
    
def wait_for_spark_job_completion(credentials, job_id, wait_interval_sec=60):
    printLog("Waiting for spark job completion for job_id=",job_id)
    run_status=get_spark_job_status(credentials, job_id)
    while run_status in ['running','starting','idle']:
        time.sleep(wait_interval_sec)
        run_status = get_spark_job_status(credentials, job_id)
    printLog("Job complete with status=",run_status)
    return run_status
    

# Submit a spark job and wait for its completion
# https://cloud.ibm.com/docs/services/AnalyticsEngine?topic=AnalyticsEngine-livy-api
# https://github.com/cloudera/livy#rest-api
def run_spark_job_to_completion(credentials, job_config_path):
    printLog("Submit spark job")
    # Submit job
    headers = {'Content-Type': 'application/json', 'X-Requested-By': 'livy'}
    url = credentials['service_endpoints']['livy']    
    with open(job_config_path) as json_file:  
        data = json.load(json_file)

    response = requests.post(url, headers=headers, data=json.dumps(data), auth=(credentials['username'], credentials['password']))
    printLog(response.text)
    job_id = response.json()['id']    
    run_status = wait_for_spark_job_completion(credentials, job_id)
    log = get_spark_job_log(credentials, job_id)
    return log


init()
