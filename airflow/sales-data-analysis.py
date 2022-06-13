
import json
import requests
from datetime import datetime

from airflow import DAG
from airflow.providers.http.operators.http import SimpleHttpOperator
from airflow.operators.python import PythonOperator
from airflow.sensors.python import PythonSensor
from airflow.models import Variable


url = 'https://api.us-south.ae.cloud.ibm.com/v3/analytics_engines/'
instance_id='CHANGEME'
api_key = Variable.get("api_key")

def _get_iam_token(ti):
    iam_end_point='https://iam.cloud.ibm.com/identity/token'
    headers={"Authorization": "Basic Yng6Yng=","Content-Type": "application/x-www-form-urlencoded"}
    data="grant_type=urn:ibm:params:oauth:grant-type:apikey&apikey="+api_key
    res = requests.post(url=iam_end_point,headers=headers,data=data)
    access_token= json.loads(res.text)['access_token']
    ti.xcom_push(key='access_token', value= access_token)


def _track_application(region,ti):
    key=region +'_application_id'
    application_id=ti.xcom_pull(key=key)
    print('for key : ' +  key + ', pulling application_id:' + application_id)
    access_token=ti.xcom_pull(key='access_token')
    headers = {'Authorization': 'Bearer ' + access_token}
    finalurl = url+instance_id+'/spark_applications/'+application_id+'/state'
    res = requests.get(finalurl,headers=headers)
    state = json.loads(res.text)['state']
    if state == 'finished':
       return True
    else:
       return False

def _sales_data(region,ti):
    access_token=ti.xcom_pull(key='access_token')
    headers = {"Authorization": "Bearer " + access_token, "Content-type": "application/json"}
    finalurl = url+instance_id+'/spark_applications'
    data=json.dumps({"application_details": {"application": "/opt/ibm/spark/examples/src/main/python/wordcount.py","arguments": ["/opt/ibm/spark/examples/src/main/resources/people.txt"]}})
    res = requests.post(finalurl,headers=headers,data=data)
    application_id = json.loads(res.text)['id']
    key=region+'_application_id'
    ti.xcom_push(key, value= application_id)
    print('for key : ' +  key + ', pushing application_id:' + application_id)
  

dag = DAG(
    'sales_data_analysis',
    default_args={'retries': 1},
    start_date=datetime(2021, 1, 1),
    catchup=False,
)

dag.doc_md = __doc__

start = PythonOperator(
    task_id = 'start',
    python_callable= _get_iam_token,
    dag=dag)


analyze_sales_data_america = PythonOperator(
    task_id = 'analyze_sales_data_america',
    python_callable= _sales_data,
    op_kwargs={'region':'america'},
    dag=dag)


track_application_america = PythonSensor(
    task_id = 'track_application_america',
    python_callable= _track_application,
    op_kwargs={'region':'america'},
    dag=dag)

analyze_sales_data_europe = PythonOperator(
    task_id = 'analyze_sales_data_europe',
    python_callable= _sales_data,
    op_kwargs={'region':'europe'},
    dag=dag)


track_application_europe = PythonSensor(
    task_id = 'track_application_europe',
    python_callable= _track_application,
    op_kwargs={'region':'europe'},
    dag=dag)

analyze_sales_data_asia = PythonOperator(
    task_id = 'analyze_sales_data_asia',
    python_callable= _sales_data,
    op_kwargs={'region':'asia'},
    dag=dag)

track_application_asia = PythonSensor(
    task_id = 'track_application_asia',
    python_callable= _track_application,
    op_kwargs={'region':'asia'},
    dag=dag)

analyze_overall_trends = PythonOperator(
    task_id = 'analyze_overall_trends',
    python_callable= _sales_data,
    op_kwargs={'region':'overall'},
    dag=dag)

track_application_overall = PythonSensor(
    task_id = 'track_application_overall',
    python_callable= _track_application,
    op_kwargs={'region':'overall'},
    dag=dag)

start >> [ analyze_sales_data_america, analyze_sales_data_europe, analyze_sales_data_asia ] 
analyze_sales_data_america >> track_application_america
analyze_sales_data_europe >> track_application_europe
analyze_sales_data_asia >> track_application_asia
[track_application_america, track_application_europe, track_application_asia] >> analyze_overall_trends >> track_application_overall
