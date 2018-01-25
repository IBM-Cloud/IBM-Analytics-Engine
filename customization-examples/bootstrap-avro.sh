# TODO:
#
# One improvement to this script would be to put the avro packages in their own directory, e.g. /home/clsadmin/spark-avro 
# so that they are managed separately from /home/common/lib/scala/spark2/.  This change will require

# FIXME:
# The ambari service may not be ready after running this script - how do we check (and wait) until ambari has finished?


DESTDIR=/home/common/lib/scala/spark2/
TMPDIR=$(mktemp -d)

if [ ! -d apache-ivy-2.4.0 ]; then
   wget -q -c http://apache.mirror.anlx.net//ant/ivy/2.4.0/apache-ivy-2.4.0-bin.zip
   unzip apache-ivy-2.4.0-bin.zip
fi

cat << EOF > ivysettings.xml
<ivysettings>
    <settings defaultResolver="chain"/>
    <caches  defaultCacheDir="${TMPDIR}" />
    <resolvers>
        <chain name="chain">
            <ibiblio name="central" m2compatible="true"/>
        </chain>
    </resolvers>
</ivysettings>
EOF

java -jar apache-ivy-2.4.0/ivy-2.4.0.jar -settings ivysettings.xml -dependency com.databricks spark-avro_2.11 4.0.0

find $TMPDIR -name *.jar | xargs cp -t $DESTDIR

rm -rf $TMPDIR

if [ "x$NODE_TYPE" == "xmanagement-slave2" ]
then
    echo "stop and Start Services"
    curl -k -v --user $AMBARI_USER:$AMBARI_PASSWORD -H "X-Requested-By: ambari" -i -X PUT -d '{"RequestInfo": {"context": "Stop All Services via REST"}, "ServiceInfo": {"state":"INSTALLED"}}' https://$AMBARI_HOST:$AMBARI_PORT/api/v1/clusters/$CLUSTER_NAME/services
    sleep 200

    curl -k -v --user $AMBARI_USER:$AMBARI_PASSWORD -H "X-Requested-By: ambari" -i -X PUT -d '{"RequestInfo": {"context": "Start All Services via REST"}, "ServiceInfo":{"state":"STARTED"}}' https://$AMBARI_HOST:$AMBARI_PORT/api/v1/clusters/$CLUSTER_NAME/services
    sleep 700
fi