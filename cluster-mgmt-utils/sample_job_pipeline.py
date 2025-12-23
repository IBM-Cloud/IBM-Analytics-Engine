from manage_iae_cluster_utils import *
from datetime import datetime

############# arguments ###########

region = 'us-south'  # us-south, eu-gb, jp-tok or eu-de
bmx_api_key = "<BLUEMIX PLATFORM API KEY>"
                
# parameters for cluster provisoning
iae_name = "<NAME OF IAE Cluster>"
resource_group_name = "<BLUEMIX RESOURCE GROUP NAME>"
compute_node_count = 1  # Max 20
hardware_config = 'default'   # default or memory-intensive
iae_plan="hourly"   # lite, hourly or monthly

# parameters for customization script
git_token = "<GITHUB TOKEN>"
git_org = "<GITHUB ORG NAME>"  # e.g. WCP-Consumption-Tech 
git_user = "<GITHUB USER NAME/EMAIL ID>"  # e.g wcpct@us.ibm.com
git_script_path = "<GITHUB URL for SCRIPT>" # e.g. https://raw.github.ibm.com/WCP-Consumption-Tech/wcpct-datascience/master/pylib/fixIAE.sh
script_params="" # parameters for script, if any

# spark app to submit
app_config_path = "sample_app_config.json" # path to the json file which contains spark submit parameters

############# end arguments ###########

###### Cluster creation and job submission pipeline ######
init(region)

run_cluster_provision(bmx_api_key, iae_name, resource_group_name, compute_node_count, hardware_config, iae_plan)

# Save credentials with password and service endpoints. Would be required to login into Ambari/Sparkhistory UI
credentials = get_cluster_credentials(bmx_api_key, iae_name)
with open(iae_name +'_credentials.json', 'w') as outfile:  
    json.dump(credentials, outfile)
    
run_cluster_customization(bmx_api_key, iae_name, git_token, git_org, git_user, git_script_path, script_params)
        
app_log = run_spark_job_to_completion(credentials, app_config_path)
log_file_name = 'app_log_'+ datetime.now().strftime("%Y%m%d%H%M%S") + '.txt'
with open(log_file_name, 'w') as f:
    for line in app_log:
        f.write("%s\n" % line)
        
run_cluster_deletion(bmx_api_key, iae_name)

print("Done!")