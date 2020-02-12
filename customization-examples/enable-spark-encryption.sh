#!/bin/bash
#------------------------------------------------------------------------------
# Adhoc Customization script to enable spark encryption in clusters
#------------------------------------------------------------------------------

# Helper functions

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
        echo " Service already stopped"
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
        echo " Service already started"
    elif [[ "$httpResp" != "202" ]]
    then
               echo "Error initiating start for the affected services, API response: $httpResp"
               exit 1
    else
               echo "Request accepted. Service start in progress...${response::-3}"
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
        echo "status: $status 1"
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
                echo "Progress: $status 2"
                sleep 5s
                echo "status: $status 3"
        done
}

 

# Validate input
if [ $# -ne 1 ]
then 
	 echo "Usage: $0  <cluster_password>"
else
	CLUSTER_PASSWORD="$1"
fi

# Actual customization starts here
if [ "x$NODE_TYPE" == "xmanagement-slave2" ]
then 
    echo "Updating Knox Topology properties"
    /usr/bin/python /var/lib/ambari-server/resources/scripts/configs.py -s https --user=$AMBARI_USER --password=$CLUSTER_PASSWORD --port=$AMBARI_PORT --action=get --host=$AMBARI_HOST --cluster=$CLUSTER_NAME --config-type=topology --file=topo.json
    SPARK_HOST=`grep :18081 topo.json | awk -F"http://" '{print $2}' | awk -F":" '{print $1}'`
    echo $SPARK_HOST
    sed -i "s,<url>http://$SPARK_HOST:18081</url>,<url>https://$SPARK_HOST:18481</url>,g" topo.json
    /usr/bin/python /var/lib/ambari-server/resources/scripts/configs.py -s https --user=$AMBARI_USER --password=$CLUSTER_PASSWORD --port=$AMBARI_PORT --action=set --host=$AMBARI_HOST --cluster=$CLUSTER_NAME --config-type=topology --file=topo.json
    echo "Stop Service Knox"
    stopService KNOX
    echo "Start Service Knox"
    startService KNOX
fi
