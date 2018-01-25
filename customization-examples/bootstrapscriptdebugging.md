# How to debug your boostrap script

Debugging your customization if needed requires additional steps. The main reason this is challenging is that the script runs on the cluster nodes rather than your workstation. It will be launched on all nodes but, parts of it will only run on one node ( Usually slave2 ). This topic may help you figure out where things are breaking.

If `bx cf service <cluster-name>` shows status of "create succeeded" but from the IBM Cloud console you see the cluster status stays in "Customizing" you can dig into the status of the customization job.

## Job status

To monitor the customization jobs directly you can use the `curl` commands described in [Tracking the status of the customizaton](https://console.stage1.bluemix.net/docs/services/AnalyticsEngine/customizing-cluster.html#getting-cluster-status) .

To summarize those instructions:

To use the curl commands you need two pieces of information you likely dont have already from `bx cf` commands.

These are your IAM access token and your cluster `service_instance_id`

Use `bx iam oauth-tokens` to retrieve the IAM access token. You dont need the UAA Token from the response.

```
bx iam oauth-tokens

IAM token:  Bearer eyJraWQiOiIyMDE3MTAzMC0wMDowMDowMCIsImFsZyI6IlJTMjU2In0.eyJpYW1faWQiOiJJQk1pZC0yNzAwMDBFWDhHIiwiaWQiOiJJQk1pZC0yNzAwMDBFWDhHIiwicmVhbG1pZCI6IklCTWlkIiwiaWRlbnRpZmllciI6IjI3MDAwMEVYOEciLCJnaXZlbl9uYW1lIjoiU3RlcGhlbiIsImZhbWlseV9uYW1lIjoiSHVzc2V5IiwibmFtZSI6IlN0ZXBoZW4gSHVzc2V5IiwiZW1haWwiOiJzaHVzc2V5QHVzLmlibS5jb20iLCJXXXXXzaHVzc2V5QHVzLmlibS5jb20iLCJhY2NvdW50Ijp7ImJzcyI6IjcxM2M3ODNkOWE1MDdhNTMxMzVmZTY3OTNjNjU4MWU5IiwiaW1zIjoiMTQxNTYyMyJ9LCJpYXQiOjE1MTYzODM1MjgsImV4cCI6MTUxNjM4NzEyOCwiaXNzIjoiaHR0cHM6Ly9pYW0uYmx1ZW1peC5uZXQvaWRlbnRpdHkiLCJncmFudF90eXBlIjoidXJuOmlibTpwYXJhbXM6b2F1dGg6Z3JhbnQtdHlwZTphcGlrZXkiLCJzY29wZSI6Im9wZW5pZCIsImNsaWVudF9pZCI6ImJ4In0.MBryNgJJrQ-3-Hn6cJdvLQAtNGNn5ish1XvL0X_m8_YqQSqiMYAAgvabrumGBUnMiXAt88R-9gxsZPlc_rh4_O61Q65jOfD2mK0OvTGrnILPOFVpyscH_4A90vTjHnCeza2ZDgVMTCKPNmID2tCXMXXNfqSQSXQHkl5aj34Dg3d-GC02rFpUx90hEQv5jCmwlXTjDGnNCFBdEpZA-V3irhZo9UJPOQ1-dVQ1aazgUFEV-UgkBT_P-OtSOjOmZhaQ7zgdmKnLfMrR-xCGRc22KUGmELiAuslVf4hnMks_4fQHufDo8HR5YxJblA-mYtv_U49wGZMt_erZH3amU1GP6w
UAA token:  bearer eyJhbGciOiJIUzI1NiIsImtpZCI6ImtleS0xIiwidHlwIjoiSldUIn0.eyJqdGkiOiJhNTVjMTA1NDc5ZDM0NTZkYTE4ZjBjODQ4MzQ4MmQxZCIsInN1YiI6IjVjNjA3ZmQxLWIwNWItNDQ1Mi05ZTFmLWEzYjQ3NDRkMmJlMiIsInNjb3BlIjpbImNsb3VkX2NvbnRyb2xsZXIucmVhZCIsInBhc3N3b3JkLndyaXRlIiwiY2xvdWRfY29udHJvbGxlci53cml0ZSIsIm9wZW5pZCIsInVhYS51c2VyIl0sImNsaWVudF9pZCI6ImNXXXXXXiY2YiLCJhenAiOiJjZiIsImdyYW50X3R5cGUiOiJwYXNzd29yZCIsInVzZXJfaWQiOiI1YzYwN2ZkMS1iMDViLTQ0NTItOWUxZi1hM2I0NzQ0ZDJiZTIiLCJvcmlnaW4iOiJ1YWEiLCJ1c2VyX25hbWUiOiJzaHVzc2V5QHVzLmlibS5jb20iLCJlbWFpbCI6InNodXNzZXlAdXMuaWJtLmNvbSIsImlhdCI6MTUxNjM4MzUyOSwiZXhwIjoxNTE3NTkzMTI5LCJpc3MiOiJodHRwczovL3VhYS5uZy5ibHVlbWl4Lm5ldC9vYXV0aC90b2tlbiIsInppZCI6InVhYSIsImF1ZCI6WyJjbG91ZF9jb250cm9sbGVyIiwicGFzc3dvcmQiLCJjZiIsInVhYSIsIm9wZW5pZCJdfQ.-ZmVEd5UzVBpc78fgsQqutg2wgCWgR04k3RnCPDLTuc
```

For the `service_instance_id` ( aka `instance_id` ), this is not the instance name you used to create it. You can get the right value from the credentials of your cluster. If you already created them you can skip the first command.

```
bx cf create-service-key <cluster name> Credentials1 -c {}
bx cf service-key <cluster name> Credentials1 
```
The `instance_id` property is likely at the end of the response.

```
...  
 },
 "cluster_management": {
  "api_url": "https://api.dataplatform.ibm.com/v2/analytics_engines/a6ea95b9-ad5e-4f2f-b332-dea853f381ac",
  "instance_id": "a6ea95b9-ad5e-4f2f-b332-dea853f381ac"
 }
}
```
Use both of these properties to create the curl command that lists customization job ids in the following form.

```
curl -X GET https://api.dataplatform.ibm.com/v2/analytics_engines/<service_instance_id>/customization_requests -H 'Authorization: Bearer <user's IAM access token>'
```

The response looks like this

```
[{"id":"13359"}]
```

Add the id to the url in the command you just used in this form to get the detailed status.

```
curl -X GET https://api.dataplatform.ibm.com/v2/analytics_engines/<service_instance_id>/customization_requests/<request_id> -H 'Authorization: Bearer <user's IAM access token>'
```

It looks like this in raw form.

```
{"id":"13359","run_status":"Completed","run_details":{"overall_status":"success","details":[{"node_name":"chs-flf-777-mn002.bi.services.us-south.bluemix.net","node_type":"management-slave1","start_time":"2018-01-19 17:03:13.633000","end_time":"2018-01-19 17:03:16.825000","time_taken":"3 secs","status":"CustomizeSuccess","log_file":"/var/log/chs-flf-777-mn002.bi.services.us-south.bluemix.net_13359.log"},{"node_name":"chs-flf-777-mn003.bi.services.us-south.bluemix.net","node_type":"management-slave2","start_time":"2018-01-19 17:03:15.108000","end_time":"2018-01-19 17:14:01.376000","time_taken":"646 secs","status":"CustomizeSuccess","log_file":"/var/log/chs-flf-777-mn003.bi.services.us-south.bluemix.net_13359.log"},{"node_name":"chs-flf-777-dn001.bi.services.us-south.bluemix.net","node_type":"data","start_time":"2018-01-19 17:03:16.344000","end_time":"2018-01-19 17:03:24.302000","time_taken":"7 secs","status":"CustomizeSuccess","log_file":"/var/log/chs-flf-777-dn001.bi.services.us-south.bluemix.net_13359.log"}]}}
```

Values for `run_status` and `overall_status` and most helpful. The location of the log files in each node are also useful however their location is consistent and their naming is easy to spot so if you just want to jump to the logs, as a shortcut you can connect to the cluster using the `ssh` command  and password from the `bx cf service-key ...` command response. Look for the log in the `/var/log` folder. The log filename will be similar in format to `chs-cvu-690-mn003.bi.services.us-south.bluemix.net_8997.log`. E.g.:-

## ssh to the nodes and diagnose

The ssh url returned by the `bx cf service-key ...` command will be the management_slave2 node in the cluster. If you want to examine other nodes, browse to the Dashboard and expand the Nodes list to see the other hostnames. 

You **cannot** connect to `master_management` but all other management nodes should be directly accessible.

If you need to connect to a compute node, you can only do this if you are already ssh connected to a master node as they have no public IP address.

Log on and find the bootstrap log file

```
ssh clsadmin@chs-cvu-690-mn003.bi.services.us-south.bluemix.net

The authenticity of host 'chs-cvu-690-mn003.bi.services.us-south.bluemix.net (169.60.137.171)' can't be established.
ECDSA key fingerprint is SHA256:5dITfzFQIP9ZvKqJwsE582IlHRbFzPM+jq7dvipJ6oc.
Are you sure you want to continue connecting (yes/no)? yes
Warning: Permanently added 'chs-cvu-690-mn003.bi.services.us-south.bluemix.net,169.60.137.171' (ECDSA) to the list of known hosts.
clsadmin@chs-cvu-690-mn003.bi.services.us-south.bluemix.net's password: 
Last login: Wed Dec 13 19:58:14 2017

[clsadmin@chs-cvu-690-mn003 ~]$ cd /var/log

[clsadmin@chs-cvu-690-mn003 log]$ ls -l chs*
-rw-r--r--. 1 root root 52804 Jan 19 17:14 chs-flf-777-mn003.bi.services.us-south.bluemix.net_13359.log
```

A command like `more <filename>` will let you page through the log to diagnose issues. 

If the script is still running you can watch the ongoing log messages using `tail -f <filename>`. Use Ctrl-C to terminate it when done.


If your customization makes changes to the filesystem you can check if they were performed correctly. For example, the Avro customization adds jar files to the  `/home/common/lib/scala/spark2/` folder. You can navigate there and look to ensure the contents is as expected. Since the bootstrap scripts run as the user `clsadmin` and most baseline files do not use that user, you can tell which files your script created or modified using `ls -l`.



As with any script there are many potential failure points. Failing to download it from the location you chose to host your boostrap.sh is an issue I encountered while creating this tutorial. 

While connected via ssh you can try using `wget` with the url to your bootstrap-avro.sh to check the location is reacheable from the cluster nodes. This is also a quick way to get the file onto a node so you can run it maunally if you want to make changes or enhancments for your purposes.
