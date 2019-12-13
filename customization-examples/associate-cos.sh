#!/bin/bash
#------------------------------------------------------------------------------
# Customization script to associate a COS instance with an IAE
# cluster. It expects COS credentials in AWS style. Specifically these three 
# arguments: <s3_endpoint> <s3_access_key> <s3_secret_key> <cluster_password>
#------------------------------------------------------------------------------

# Helper functions

# Parse json and return value for the specified json path
# Parse json and return value for the specified json path
parseJson ()
{
        jsonString=$1
        jsonPath=$2
        jsonValue=''
        jsonString=`echo $jsonString | grep ${jsonPath}`
        #echo "json string is $jsonString"
        case $jsonPath in
             "href")
                jsonValue=`echo  $jsonString | grep -oP '(?<="href" : ")[^"]*'`
                ;;
             "request_status")
                jsonValue=`echo  $jsonString | grep -oP '(?<="request_status" : ")[^"]*'`
                ;;
             "*")
                jsonValue=`echo  $jsonString | grep -oP '(?<="request_status" : ")[^"]*'`
                ;;
        esac
        echo "$jsonValue"
}

stopService ()
{
    response=`curl -u $AMBARI_USER:$CLUSTER_PASSWORD -i -H 'X-Requested-By: ambari' --silent -w "%{http_code}" -X PUT -d \
    '{"RequestInfo": {"context" :"Stop '"$1"' via REST"}, "Body": {"ServiceInfo": {"state": "INSTALLED"}}}' \
    https://$AMBARI_HOST:$AMBARI_PORT/api/v1/clusters/$CLUSTER_NAME/services/$1`
    echo "Response is $response"
    httpResp=${response:(-3)}

    echo "httpResp is $httpResp"
    if [[ "$httpResp" == "200" ]]
    then
        echo "Hive Service already stopped"
    elif [[ "$httpResp" != "202" ]]
    then
               echo "Error initiating stop for the affected services, API response: $httpResp"
               exit 1
    else
               echo "Request accepted. Hive stop in progress...${response::-3}"
               trackProgress "${response::-3}"
    fi


}

startService ()
{
    response=`curl -u $AMBARI_USER:$CLUSTER_PASSWORD -i -H 'X-Requested-By: ambari' --silent -w "%{http_code}" -X PUT -d \
    '{"RequestInfo": {"context" :"Start '"$1"' via REST"}, "Body": {"ServiceInfo": {"state": "STARTED"}}}' \
    https://$AMBARI_HOST:$AMBARI_PORT/api/v1/clusters/$CLUSTER_NAME/services/$1`
    echo "Response is $response"
    httpResp=${response:(-3)}
    echo "httpResp is $httpResp"
    if [[ "$httpResp" == "200" ]]
    then
        echo "Hive Service already started"
    elif [[ "$httpResp" != "202" ]]
    then
               echo "Error initiating start for the affected services, API response: $httpResp"
               exit 1
    else
               echo "Request accepted. Hive start in progress...${response::-3}"
               trackProgress "${response::-3}"
    fi

}

# Track progress using the call back returned by Ambari start/stop API
trackProgress ()
{
        response=$1
        #echo " Inside trackProgress $response"
        # Extract call back to from response to track progress
        parseJson "$response" "href"
        progressUrl=${jsonValue}
        # Progress tracking loop
        status="started"
    while [ "$status" != "COMPLETED" ]
        do
        progressResp=`curl -k -u $AMBARI_USER:$CLUSTER_PASSWORD -H 'X-Requested-By:ambari' -X GET $progressUrl --silent`
                parseJson "$progressResp" "request_status"
                status=${jsonValue}
                if [ "$status" == "COMPLETED" ]
                then
                        echo "Start/Stop operation completed sucessfully"
                        break
                elif [ "$status" == "FAILED" ]
                then
                        echo "Start/Stop operation failed"
                        exit 1
                fi
                sleep 5s
        done
}


# Validate input
if [ $# -ne 4 ]
then 
	 echo "Usage: $0 <s3_endpoint> <s3_access_key> <s3_secret_key> <cluster_password>"
else
	S3_ENDPOINT="$1"
	S3_ACCESS_KEY="$2"
	S3_SECRET_KEY="$3"
	AMBARI_PASSWORD="$4"
fi

# Actual customization starts here
# Note : For existing HDP 2.6.2 clusters, please use configs.sh for cluster customization
# For new HDP 2.6.2 or 2.6.5 clusters, the following customization using configs.py will work
if [ "x$NODE_TYPE" == "xmanagement-slave2" ]
then 
    echo "Updating Ambari properties"
    /usr/bin/python /var/lib/ambari-server/resources/scripts/configs.py -s https --user=$AMBARI_USER --password=$AMBARI_PASSWORD --port=$AMBARI_PORT --action=set --host=$AMBARI_HOST --cluster=$CLUSTER_NAME --config-type=core-site -k "fs.cos.myprodservice.access.key" -v $S3_ACCESS_KEY
    /usr/bin/python /var/lib/ambari-server/resources/scripts/configs.py -s https --user=$AMBARI_USER --password=$AMBARI_PASSWORD --port=$AMBARI_PORT --action=set --host=$AMBARI_HOST --cluster=$CLUSTER_NAME --config-type=core-site -k "fs.cos.myprodservice.endpoint" -v $S3_ENDPOINT
    /usr/bin/python /var/lib/ambari-server/resources/scripts/configs.py -s https --user=$AMBARI_USER --password=$AMBARI_PASSWORD --port=$AMBARI_PORT --action=set --host=$AMBARI_HOST --cluster=$CLUSTER_NAME --config-type=core-site -k "fs.cos.myprodservice.secret.key" -v $S3_SECRET_KEY


#    echo 'Restart affected services'
#    response=`curl -k -u $AMBARI_USER:$AMBARI_PASSWORD -H 'X-Requested-By: ambari' --silent -w "%{http_code}" -X POST -d '{"RequestInfo":{"command":"RESTART","context":"Restart all required services","operation_level":"host_component"},"Requests/resource_filters":[{"hosts_predicate":"HostRoles/stale_configs=true"}]}' https://$AMBARI_HOST:$AMBARI_PORT/api/v1/clusters/$CLUSTER_NAME/requests` 
	
#    httpResp=${response:(-3)}
#    if [[ "$httpResp" != "201" ]]
#    then
#		echo "Error initiating restart for the affected services, API response: >$httpResp<"
#		exit 1
#    else
#		echo "Request accepted. Service restart in progress...${response::-3}"
#		trackProgress "${response::-3}"

	stopService HDFS
	startService HDFS

	stopService YARN
	startService YARN

	stopService HIVE
	startService HIVE

	stopService SPARK
	startService SPARK
fi
