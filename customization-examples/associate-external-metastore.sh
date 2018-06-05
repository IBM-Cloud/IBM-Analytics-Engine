#!/bin/bash
#-----------------------------------------------------------------------
# Customization script to point an IAE cluster's, Hive meta-store to an 
# external mysql database. It is recommended to use Compose for MySQL
# as an external db. This scripts expects following four arguments:
# <db_user> <db_password> <db_name> <db_conn_url>
# Connection url shall be specified in the following format
# jdbc:mysql://<dbHost>:<dbPort>/<dbName>
#-----------------------------------------------------------------------

# Helper functions

# Parse json and return value for the specified json path
parseJson ()
{
	jsonString=$1
	jsonPath=$2
		
	echo $(echo $jsonString | python -c "import json,sys; print json.load(sys.stdin)$jsonPath") 
}

# Track progress using the call back returned by Ambari restart API
trackProgress ()
{
	response=$1
	# Extract call back to from response to track progress
	progressUrl=$(parseJson "$response" '["href"]')
	echo "Link to track progress: $progressUrl"

	# Progress tracking loop	
	tempPercent=0
    while [ "$tempPercent" != "100.0" ]
	do
        progressResp=`curl -k -u $AMBARI_USER:$AMBARI_PASSWORD -H 'X-Requested-By:ambari' -X GET $progressUrl --silent`
		tempPercent=$(parseJson "$progressResp" '["Requests"]["progress_percent"]')
		echo "Progress: $tempPercent"
		sleep 5s
	done
	
	# Validate if restart has really succeeded
	if [ "$tempPercent" == "100.0" ]
	then
		# Validate that the request is completed
		progressResp=`curl -k -u $AMBARI_USER:$AMBARI_PASSWORD -H 'X-Requested-By:ambari' -X GET $progressUrl --silent`
		finalStatus=$(parseJson "$progressResp" '["Requests"]["request_status"]')
		if [ "$finalStatus" == "COMPLETED" ]
        then
        	echo 'Restart of affected service succeeded.'
            exit 0
        else
        	echo 'Restart of affected service failed'
            exit 1
        fi
	else
		echo 'Restart of affected service failed'
		exit 1
	fi
}

# Validate input
if [ $# -ne 4 ]
then 
	 echo "Usage: $0 <db_user> <db_password> <db_name> <db_conn_url>"
else
	DB_USER_NAME="$1"
	DB_PWD="$2"
	DB_NAME="$3"
	DB_CXN_URL="$4"
fi


# Actual customization starts here
# Note : For existing HDP 2.6.2 clusters, please use configs.sh for cluster customization
# For new HDP 2.6.2 or 2.6.5 clusters, the following customization using configs.py will work
if [ "x$NODE_TYPE" == "xmanagement-slave2" ]
then 
     echo "Updating Ambari properties"
     python /var/lib/ambari-server/resources/scripts/configs.py -s https --user=$AMBARI_USER --password=$AMBARI_PASSWORD --port=$AMBARI_PORT --action=set --host=$AMBARI_HOST --cluster=$CLUSTER_NAME --config-type=hive-site -k "javax.jdo.option.ConnectionURL" -v $DB_CXN_URL
     python /var/lib/ambari-server/resources/scripts/configs.py -s https --user=$AMBARI_USER --password=$AMBARI_PASSWORD --port=$AMBARI_PORT --action=set --host=$AMBARI_HOST --cluster=$CLUSTER_NAME --config-type=hive-site -k "javax.jdo.option.ConnectionUserName" -v $DB_USER_NAME
     python /var/lib/ambari-server/resources/scripts/configs.py -s https --user=$AMBARI_USER --password=$AMBARI_PASSWORD --port=$AMBARI_PORT --action=set --host=$AMBARI_HOST --cluster=$CLUSTER_NAME --config-type=hive-site -k "javax.jdo.option.ConnectionPassword" -v $DB_PWD
     python /var/lib/ambari-server/resources/scripts/configs.py -s https --user=$AMBARI_USER --password=$AMBARI_PASSWORD --port=$AMBARI_PORT --action=set --host=$AMBARI_HOST --cluster=$CLUSTER_NAME --config-type=hive-site -k "ambari.hive.db.schema.name" -v $DB_NAME   
     
    echo 'Restart services/components affected by Hive configuration change'
    response=`curl -k -u $AMBARI_USER:$AMBARI_PASSWORD -H 'X-Requested-By: ambari' --silent -w "%{http_code}" -X POST -d '{"RequestInfo":{"command":"RESTART","context":"Restart all required services","operation_level":"host_component"},"Requests/resource_filters":[{"hosts_predicate":"HostRoles/stale_configs=true"}]}' https://$AMBARI_HOST:$AMBARI_PORT/api/v1/clusters/$CLUSTER_NAME/requests` 
	
    httpResp=${response:(-3)}
    if [[ "$httpResp" != "202" ]]
    then
		echo "Error initiating restart for the affected services, API response: $httpResp"
		exit 1
    else
		echo "Request accepted. Hive restart in progress...${response::-3}"
		trackProgress "${response::-3}"
    fi
fi
