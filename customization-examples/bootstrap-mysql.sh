# Helper functions for service restart

function stopAllServices(){

  response=$(curl -s --user $AMBARI_USER:$AMBARI_PASSWORD -X PUT \
   https://$AMBARI_HOST:$AMBARI_PORT/api/v1/clusters/$CLUSTER_NAME/services \
  -H 'Cache-Control: no-cache' \
  -H 'X-Requested-By: ambari' \
  -d '{
	"RequestInfo": {
		"context": "Stop All Services via REST"
		},
	"ServiceInfo": {
		"state":"INSTALLED"
		}
}'
)

# echo "stopAllServices: $?"
}


function startAllServices(){

  response=$(curl -s --user $AMBARI_USER:$AMBARI_PASSWORD -X PUT \
   https://$AMBARI_HOST:$AMBARI_PORT/api/v1/clusters/$CLUSTER_NAME/services \
  -H 'Cache-Control: no-cache' \
  -H 'X-Requested-By: ambari' \
  -d '{
	"RequestInfo": {
		"context": "Start All Services via REST"
		},
	"ServiceInfo": {
		"state":"STARTED"
		}
}'
)

# echo "startAllServices: $?"

}

function requestStatus(){

  response=$(curl -s --user $AMBARI_USER:$AMBARI_PASSWORD -X GET \
  https://$AMBARI_HOST:$AMBARI_PORT/api/v1/clusters/$CLUSTER_NAME/requests/$1?fields=Requests/request_status \
  -H 'Cache-Control: no-cache'
  )

 #  echo "requestStatus: $?"
}


extractJSONPropertvalue(){
  propertyValueElement="1"
  
  extractedJSONPropertvalue=$(echo $response | awk -F"[,:}]" '{for(i=1;i<=NF;i++){if($i~/\042'$1'\042/){print $(i+1)}}}' | tr -d '"' | sed -n ${propertyValueElement}p )
  echo "$1 = $extractedJSONPropertvalue"
}


function ambariStopAll(){

# Since there are a few ways for this to fail that might not be trapped, the default status is set to FAILED
ambariStopAllStatus="FAILED"


echo "Stopping all services"
stopAllServices

# Check if the action was accepted
extractJSONPropertvalue "status"
stopStatus=$extractedJSONPropertvalue

# If it was accepted get the ID of the async request
extractJSONPropertvalue "id"
requestId="$extractedJSONPropertvalue"

finished=0
echo "Checking status of request: $requestId"
  while [ $finished -ne 1 ]
  do
    
  # Using the ID ge the request details
  requestStatus $requestId

  # Extract the status from the request details. This is what we would monitor until done. Loop requestStatus while this is "IN_PROGRESS"
  extractJSONPropertvalue "request_status"
  requestCompleted="$extractedJSONPropertvalue"

    # Possible values COMPLETED, FAILED, PENDING(IF more than one start is sent)
    if [ $requestCompleted = "COMPLETED" ] 
    then
      echo "Completed"
      ambariStopAllStatus="COMPLETED"
      finished=1
    fi

    if [ $requestCompleted = "FAILED" ] 
    then
      echo "Failed"
      finished=1
    fi


    sleep 10
  done

}

function ambariStartAll(){

# Since there are a few ways for this to fail that might not be trapped, the default status is set to FAILED
ambariStartAllStatus="FAILED"

echo "Starting all services"
startAllServices

# echo "Response: $response"

# Check if the action was accepted
extractJSONPropertvalue "status"
stopStatus=$extractedJSONPropertvalue

# If it was accepted get the ID of the async request
extractJSONPropertvalue "id"
requestId="$extractedJSONPropertvalue"

finished=0
echo "Checking status of request: $requestId"
  while [ $finished -ne 1 ]
  do
    
  # Using the ID get the request details
  requestStatus $requestId

  # Extract the status from the request details. This is what we would monitor until done. Loop requestStatus while this is "IN_PROGRESS"
  extractJSONPropertvalue "request_status"
  requestCompleted="$extractedJSONPropertvalue"
  
    # Possible values COMPLETED, FAILED, PENDING(IF more than one start is sent)
    if [ $requestCompleted = "COMPLETED" ] 
    then
      echo "Completed"
      ambariStartAllStatus="COMPLETED"
      finished=1
    fi

    if [ $requestCompleted = "FAILED" ] 
    then
      echo "Failed"
      finished=1
    fi


    sleep 10
  done

}


# End of helper functions


# Start of main code

# Capture parameters passed in to the script
# Assumes IAE customization JSON includes "script_params": ["DB_USER_NAME", "DB_PWD", "DB_NAME", "DB_CXN_URL_HOST" , "DB_CXN_URL_PORT"]

DB_USER_NAME=$1
DB_PWD=$2
DB_NAME=$3
DB_CXN_URL_HOST=$4
DB_CXN_URL_PORT=$5
DB_CXN_URL="jdbc:mysql://"$DB_CXN_URL_HOST":"$DB_CXN_URL_PORT"/$DB_NAME?createDatabaseIfNotExist=true"

# Uncomment to debug if needed
# echo "MySQL User: $DB_USER_NAME"
# echo "MySQL DB Name: $DB_NAME"
# echo "MySQL HOST: $DB_CXN_URL_HOST"
# echo "MySQL PORT: $DB_CXN_URL_PORT"
# echo "MySQL URL: $DB_CXN_URL"
# echo "NODE_TYPE: $NODE_TYPE"

# NODE_TYPE options are data, management-slave1, or manangement-slave2
if [ "x$NODE_TYPE" == "xmanagement-slave2" ]
then
    
    echo "******* Updating settings to point to external database"

    echo "javax.jdo.option.ConnectionURL = $DB_CXN_URL"
    /var/lib/ambari-server/resources/scripts/configs.sh -u $AMBARI_USER -p $AMBARI_PASSWORD -port $AMBARI_PORT -s set $AMBARI_HOST  $CLUSTER_NAME hive-site "javax.jdo.option.ConnectionURL" $DB_CXN_URL

    echo "javax.jdo.option.ConnectionUserName = $DB_USER_NAME"
    /var/lib/ambari-server/resources/scripts/configs.sh -u $AMBARI_USER -p $AMBARI_PASSWORD -port $AMBARI_PORT -s set $AMBARI_HOST  $CLUSTER_NAME hive-site "javax.jdo.option.ConnectionUserName" $DB_USER_NAME

    # echo "javax.jdo.option.ConnectionPassword = $DB_PWD"
    /var/lib/ambari-server/resources/scripts/configs.sh -u $AMBARI_USER -p $AMBARI_PASSWORD -port $AMBARI_PORT -s set $AMBARI_HOST  $CLUSTER_NAME hive-site "javax.jdo.option.ConnectionPassword" $DB_PWD

    echo "ambari.hive.db.schema.name = $DB_NAME"
    /var/lib/ambari-server/resources/scripts/configs.sh -u $AMBARI_USER -p $AMBARI_PASSWORD -port $AMBARI_PORT -s set $AMBARI_HOST $CLUSTER_NAME hive-site "ambari.hive.db.schema.name" $DB_NAME

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
    
    echo "******* Completed customization"
fi