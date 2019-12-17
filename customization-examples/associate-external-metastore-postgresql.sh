#!/bin/bash
#-----------------------------------------------------------------------
# Customization script to point an IAE cluster's, Hive meta-store to an
# external mysql database. It is recommended to use PostGreSQL
# as an external db. This scripts expects following nine arguments:
# <db_user> <db_password> <db_name> <db_conn_url> <cluster_password>
# Connection url shall be specified in the following format
# jdbc:postgresql://<hostname>:<port>/<dbname>?sslmode=verify-ca 
# <cos_endpoint> <cos_path> <cos_access_key> <cos_secret_key>
#-----------------------------------------------------------------------

jsonValue=''
certFile="/home/wce/clsadmin/postgres.cert"

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

downloadCertFile ()
{
endPoint="$1"
resource="$2"
s3Key="$3"
s3Secret="$4"
outputFile="$certFile"
contentType="binary/octet-stream"
dateValue=`TZ=GMT date -R`
echo "DateValue $dateValue"
# You can leave our "TZ=GMT" if your system is already GMT (but don't have to)
stringToSign="GET\n\n${contentType}\n${dateValue}\n${resource}"
signature=`echo -en ${stringToSign} | openssl sha1 -hmac ${s3Secret} -binary | base64`


curl -H "Host: $endPoint" \
     -H "Date: ${dateValue}" \
     -H "Content-Type: ${contentType}" \
     -H "Authorization: AWS ${s3Key}:${signature}" \
     https://${endPoint}${resource} -o $outputFile
chmod -R 755 /home/wce/clsadmin
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
if [ $# -ne 9 ]
then
         echo "$# is the number of arguments passed"
         echo "Usage: $0 <db_user> <db_password> <db_name> <db_conn_url> <cluster_password> <cos_endpoint> <cos_path> <cos_access_key> <cos_secret_key>"
         exit 1
else
        DB_USER_NAME="$1"
        DB_PWD="$2"
        DB_NAME="$3"
        DB_CXN_URL="$4"
        CLUSTER_PASSWORD="$5"
        COS_ENDPOINT="$6"
        COS_PATH="$7"
        COS_ACCESS_KEY="$8"
        COS_SECRET_KEY="$9"
fi

#Add certificate path to connection string
DB_CXN_URL=${DB_CXN_URL}"&sslrootcert="${certFile}
echo "DB_CXN_URL is $DB_CXN_URL"

# Actual customization starts here
# Note : For existing HDP 2.6.2 clusters, please use configs.sh for cluster customization
# For new HDP 2.6.2 or 2.6.5 clusters, the following customization using configs.py will work
if [ "x$NODE_TYPE" == "xmanagement-slave1" ]
then
     echo "Download postgres certificate files"
     downloadCertFile ${COS_ENDPOINT} ${COS_PATH} ${COS_ACCESS_KEY} ${COS_SECRET_KEY}
     echo "Updating Ambari properties"
     /usr/bin/python  /var/lib/ambari-server/resources/scripts/configs.py -s https --user=$AMBARI_USER --password=$CLUSTER_PASSWORD --port=$AMBARI_PORT --action=set --host=$AMBARI_HOST --cluster=$CLUSTER_NAME --config-type=hive-site -k "javax.jdo.option.ConnectionURL" -v $DB_CXN_URL
     /usr/bin/python  /var/lib/ambari-server/resources/scripts/configs.py -s https --user=$AMBARI_USER --password=$CLUSTER_PASSWORD --port=$AMBARI_PORT --action=set --host=$AMBARI_HOST --cluster=$CLUSTER_NAME --config-type=hive-site -k "javax.jdo.option.ConnectionUserName" -v $DB_USER_NAME
     /usr/bin/python  /var/lib/ambari-server/resources/scripts/configs.py -s https --user=$AMBARI_USER --password=$CLUSTER_PASSWORD --port=$AMBARI_PORT --action=set --host=$AMBARI_HOST --cluster=$CLUSTER_NAME --config-type=hive-site -k "javax.jdo.option.ConnectionPassword" -v $DB_PWD
     /usr/bin/python  /var/lib/ambari-server/resources/scripts/configs.py -s https --user=$AMBARI_USER --password=$CLUSTER_PASSWORD --port=$AMBARI_PORT --action=set --host=$AMBARI_HOST --cluster=$CLUSTER_NAME --config-type=hive-site -k "javax.jdo.option.ConnectionDriverName" -v "org.postgresql.Driver"
     /usr/bin/python  /var/lib/ambari-server/resources/scripts/configs.py -s https --user=$AMBARI_USER --password=$CLUSTER_PASSWORD --port=$AMBARI_PORT --action=set --host=$AMBARI_HOST --cluster=$CLUSTER_NAME --config-type=hive-env -k "hive_database_type" -v "postgres"
     /usr/bin/python  /var/lib/ambari-server/resources/scripts/configs.py -s https --user=$AMBARI_USER --password=$CLUSTER_PASSWORD --port=$AMBARI_PORT --action=set --host=$AMBARI_HOST --cluster=$CLUSTER_NAME --config-type=hive-site -k "ambari.hive.db.schema.name" -v $DB_NAME

    echo 'Restart services/components affected by Hive configuration change'
    stopService HIVE
    echo "start service"
    startService HIVE
    exit 0
fi
