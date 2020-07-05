#!/bin/bash

# Utility function to parse json and return value for the specified json path
function parseJson() {
    jsonString="$1"
    jsonPath="$2"
    #    echo "json string is $jsonString"
    echo $(echo $jsonString | python -c "import json,sys; w=json.load(sys.stdin); d=json.dumps(w$jsonPath);print d")
}

# Utility function to extract the body and status for a HTTP response
processHTTPResponse() {
    HTTP_BODY="$1"
    HTTP_STATUS="$2"
}

# Utility function to post the alert notification to slack.
# If slack is not your preference, you can change this code to a notification mechanism of your choice.
post_to_slack() {
    # format message as a code block ```${msg}```
    #SLACK_MESSAGE="\`\`\`$1\`\`\`"
    SLACK_MESSAGE=$1
    case "$2" in
    "INFO")
        SLACK_ICON=':green:'
        ;;
    "WARNING")
        SLACK_ICON=':yellow:'
        ;;
    "ERROR")
        SLACK_ICON=':red:'
        ;;
    *)
        SLACK_ICON=':slack:'
        ;;
    esac
    curl -X POST --data "payload={\"channel\": \"#${SLACK_CHANNEL}\", \"text\": \"${SLACK_ICON} ${SLACK_MESSAGE} \" }" ${SLACK_URL}
}

## Function to check the status of services
checkServiceStatus() {
    
    # We don't want to check these services
    SERVICES_TO_SKIP=(MAPREDUCE2 PIG TEZ)
    HTTP_RESPONSE=$(curl --silent -u ${AMBARI_USER}:${AMBARI_PWD} -w "%{http_code}\n" -o curl_services.json -X GET https://${AMBARI_HOST_NAME}:${AMBARI_HOST_PORT}/api/v1/clusters/$CLUSTER_NAME/services/)
    processHTTPResponse "$(cat curl_services.json)" "$(echo $HTTP_RESPONSE)"
    serviceInfoJson=$HTTP_BODY
    allServiceUrls=$(echo "$serviceInfoJson" | python -c 'import sys, json; print json.dumps([x["href"] for x in json.load(sys.stdin)["items"]])')
    serviceArrayUrls=($(echo "$allServiceUrls" | python -c 'import sys, json; print json.dumps([x for x in json.load(sys.stdin)])' | tr -d '[]",'))
    for serviceUrl in "${serviceArrayUrls[@]}"; do
        #For each service get the details
        HTTP_RESPONSE=$(curl --silent -u "${AMBARI_USER}:${AMBARI_PWD}" -w "%{http_code}\n" -o curl_service_states.json -X GET ${serviceUrl})
        serviceStatesJson=$(cat curl_service_states.json)
        SERVICE_NAME_CHECK=$(parseJson "$serviceStatesJson" '["ServiceInfo"]["service_name"]' | tr -d '[]",')
        if [[ ! " ${SERVICES_TO_SKIP[@]} " =~ " ${SERVICE_NAME_CHECK} " ]];  then
            echo -e "ServiceName: $(parseJson "$serviceStatesJson" '["ServiceInfo"]["service_name"]')\n"
            echo -e "         service Alert summary: $(parseJson "$serviceStatesJson" '["alerts_summary"]')\n"
            echo -e "         service health: $(parseJson "$serviceStatesJson" '["ServiceInfo"]["state"]')\n"
            SERVICE_STATE=`echo $(parseJson "$serviceStatesJson" '["ServiceInfo"]["state"]') | tr -d '[]",'`
            SERVICE_NAME=`echo $(parseJson "$serviceStatesJson" '["ServiceInfo"]["service_name"]') | tr -d '[]",'`
            if [ "$SERVICE_STATE" = "STARTED" ]; then
                post_to_slack "The SERVICE $SERVICE_NAME is $SERVICE_STATE" "INFO"
            else
                post_to_slack "The SERVICE $SERVICE_NAME is $SERVICE_STATE" "ERROR"
            fi
        fi
    done
}

## Function to check the state of hosts of the cluster
checkHostStatus() {
    HTTP_RESPONSE=$(curl --silent -u ${AMBARI_USER}:${AMBARI_PWD} -w "%{http_code}\n" -o curl_hosts.json -X GET https://${AMBARI_HOST_NAME}:${AMBARI_HOST_PORT}/api/v1/clusters/$CLUSTER_NAME/hosts/)
    if [ $HTTP_RESPONSE -eq 200 ]; then
        get_response=$(cat curl_hosts.json)
        if [ "$get_response" = "[]" ]; then
            echo "+++++++++++++++No response json returned. Someting is wrong+++++++++++"
        fi
    fi
    processHTTPResponse "$(cat curl_hosts.json)" "$(echo $HTTP_RESPONSE)"
    allHostsJsonString=$HTTP_BODY
    allHostsUrls=$(echo "$allHostsJsonString" | python -c 'import sys, json; print json.dumps([x["href"] for x in json.load(sys.stdin)["items"]])')
    arrayUrls=($(echo "$allHostsUrls" | python -c 'import sys, json; print json.dumps([x for x in json.load(sys.stdin)])' | tr -d '[]",'))
    for hostUrl in "${arrayUrls[@]}"; do
        #For each host get the details
        HTTP_RESPONSE=$(curl --silent -u "${AMBARI_USER}:${AMBARI_PWD}" -w "%{http_code}\n" -o curl_hosts_states.json -X GET ${hostUrl})
        HOST_STATES_JSON=$(cat curl_hosts_states.json)
        echo -e "hostname: $(parseJson "$HOST_STATES_JSON" '["Hosts"]["host_name"]')\n"
        echo -e "         host Alert summary: $(parseJson "$HOST_STATES_JSON" '["alerts_summary"]')\n"
        echo -e "         host health: $(parseJson "$HOST_STATES_JSON" '["Hosts"]["host_state"]')\n"
        HOST_STATE=`echo $(parseJson "$HOST_STATES_JSON" '["Hosts"]["host_state"]') | tr -d '[]",'`
        HOST_NAME=`echo $(parseJson "$HOST_STATES_JSON" '["Hosts"]["host_name"]') | tr -d '[]",'`

        if [ "$HOST_STATE" = "HEALTHY" ]; then
            echo "The HOST $HOST_NAME is $HOST_STATE" "INFO"
        else
            post_to_slack "The HOST $HOST_NAME is $HOST_STATE" "ERROR"
        fi
    done
}


## Function to check the alerts on the cluster
checkAlertStatus() {
    HTTP_RESPONSE=$(curl --silent -u ${AMBARI_USER}:${AMBARI_PWD} -w "%{http_code}\n" -o curl_alerts.json -X GET https://${AMBARI_HOST_NAME}:${AMBARI_HOST_PORT}/api/v1/clusters/$CLUSTER_NAME/alerts/)
    if [ $HTTP_RESPONSE -eq 200 ]; then
        get_response=$(cat curl_alerts.json)
        if [ "$get_response" = "[]" ]; then
            echo "+++++++++++++++No response json returned. Someting is wrong+++++++++++"
        fi
    fi
    processHTTPResponse "$(cat curl_alerts.json)" "$(echo $HTTP_RESPONSE)"
    allAlertsJsonString=$HTTP_BODY
    allAlertsUrls=$(echo "$allAlertsJsonString" | python -c 'import sys, json; print json.dumps([x["href"] for x in json.load(sys.stdin)["items"]])')
    arrayUrls=($(echo "$allAlertsUrls" | python -c 'import sys, json; print json.dumps([x for x in json.load(sys.stdin)])' | tr -d '[]",'))
    for alertUrl in "${arrayUrls[@]}"; do
        #For each host get the details
        HTTP_RESPONSE=$(curl --silent -u "${AMBARI_USER}:${AMBARI_PWD}" -w "%{http_code}\n" -o curl_alerts_states.json -X GET ${alertUrl})
        ALERT_STATES_JSON=$(cat curl_alerts_states.json)
        echo -e "AlertName: $(parseJson "$ALERT_STATES_JSON" '["Alert"]["definition_name"]')\n"
        echo -e "         Alert health: $(parseJson "$ALERT_STATES_JSON" '["Alert"]["state"]')\n"
        ALERT_NAME=`echo $(parseJson "$ALERT_STATES_JSON" '["Alert"]["definition_name"]') | tr -d '[]",'`
        ALERT_STATE=`echo $(parseJson "$ALERT_STATES_JSON" '["Alert"]["state"]') | tr -d '[]",'`
        if [ "$ALERT_STATE" = "OK" ]; then
            echo "The ALERT $ALERT_NAME is $ALERT_STATE" "INFO"
        elif [ "$ALERT_STATE" = "WARNING" ]; then
            post_to_slack "The ALERT $ALERT_NAME is $ALERT_STATE" "WARNING"
        elif [ "$ALERT_STATE" = "CRITICAL" ]; then
            post_to_slack "The ALERT $ALERT_NAME is $ALERT_STATE" "ERROR"
        else
            post_to_slack "The ALERT $ALERT_NAME is $ALERT_STATE" 
        fi
    done
}


## Function to check if ambari is up
checkAmbariStatus() {
    if [ $(curl -silent -u ${AMBARI_USER}:${AMBARI_PWD} -X GET https://${AMBARI_HOST_NAME}:${AMBARI_HOST_PORT}/ -s -o /dev/null -m 15 -w "%{http_code}\n") -eq 200 ]; then
        echo "Ambari is HEALTHY for https://${AMBARI_HOST_NAME}:${AMBARI_HOST_PORT}\n"
        post_to_slack "Ambari is HEALTHY for https://${AMBARI_HOST_NAME}:${AMBARI_HOST_PORT}/" "INFO"
    else
        echo "Ambari is DOWN https://${AMBARI_HOST_NAME}:${AMBARI_HOST_PORT}\n"
        post_to_slack "Ambari is DOWN https://${AMBARI_HOST_NAME}:${AMBARI_HOST_PORT}/" "ERROR"
    fi
}

###################################################### MAIN STARTS HERE ##########################################################
# This is simple and easy shell script that you can use to setup monitoring on your clusters.
# You can set this to run it on a schedule - say every 5 minutes - using a cron or in a Jenkins or Travis system
# The script is based on Ambari APIs documented here https://github.com/apache/ambari/blob/trunk/ambari-server/docs/api/v1/index.md
#
# Usage: bash iae-monitoring.sh
#
###################################################### MAIN STARTS HERE ##########################################################

# Change this to fill in with parameters of your CLUSTER and SLACK information
AMBARI_HOST_NAME=chs-abc-123-mn001.us-south.ae.appdomain.cloud
AMBARI_HOST_PORT=9443
AMBARI_USER=clsadmin
AMBARI_PWD=password
CLUSTER_NAME=AnalyticsEngine
SLACK_URL=https://hooks.slack.com/services/PLACE/HOLDER/HOOK
SLACK_CHANNEL=channel-for-cluster-notifications

# Check the Ambari, Host and Service status and send slack notifications
checkAmbariStatus
checkHostStatus
checkServiceStatus
checkAlertStatus

## Cleanup
rm -f curl_hosts.json curl_hosts_states.json curl_services.json curl_service_states.json curl_alerts.json
