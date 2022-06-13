import json
import requests
from datetime import datetime

from airflow import DAG
from airflow.providers.http.operators.http import SimpleHttpOperator
from airflow.operators.python import PythonOperator
from airflow.sensors.python import PythonSensor



dag = DAG(
    'serverless_spark_pipeline',
    default_args={'retries': 1},
    start_date=datetime(2021, 1, 1),
    catchup=False,
)

dag.doc_md = __doc__


api_key='CHANGEME'

def _get_iam_token(ti):
    iam_end_point='https://iam.cloud.ibm.com/identity/token'
    headers={"Authorization": "Basic Yng6Yng=","Content-Type": "application/x-www-form-urlencoded"}
    data="grant_type=urn:ibm:params:oauth:grant-type:apikey&apikey="+api_key
    res = requests.post(url=iam_end_point,headers=headers,data=data)
    access_token= json.loads(res.text)['access_token']
    ti.xcom_push(key='access_token', value= access_token)

generate_iam_token = PythonOperator(
    task_id = 'get_iam_token',
    python_callable= _get_iam_token,
    dag=dag)


ae_url = 'https://api.us-south.ae.cloud.ibm.com/v3/analytics_engines/'
instance_id='CHANGEME'

def _submit_spark_application(ti):
    access_token=ti.xcom_pull(key='access_token')
    headers = {"Authorization": "Bearer " + access_token, "Content-type": "application/json"}
    finalurl = ae_url+instance_id+'/spark_applications'
    data=json.dumps({"application_details": {"application": "/opt/ibm/spark/examples/src/main/python/wordcount.py","arguments": ["/opt/ibm/spark/examples/src/main/resources/people.txt"]}})
    res = requests.post(finalurl,headers=headers,data=data)
    application_id = json.loads(res.text)['id']
    ti.xcom_push(key='application_id', value= application_id)


submit_spark_application = PythonOperator(
    task_id = 'submit_spark_application',
    python_callable= _submit_spark_application,
    dag=dag)



def _track_application(ti):
    application_id=ti.xcom_pull(key='application_id')
    access_token=ti.xcom_pull(key='access_token')
    headers = {'Authorization': 'Bearer ' + access_token}
    finalurl = ae_url+instance_id+'/spark_applications/'+application_id+'/state'
    res = requests.get(finalurl,headers=headers)
    state = json.loads(res.text)['state']
    if state == 'finished':
       return True
    else:
       return False

track_application = PythonSensor(
    task_id = 'track_application',
    python_callable= _track_application,
    dag=dag)



generate_iam_token >> submit_spark_application >> track_application
