#!/bin/bash

echo 'Attempting to start Jupyter notebook.  This script is experimental ...'

export VCAP_STR="$(cat vcap.json)"

# Extract variables from vcap.json.  We could have used a utility like jq, but we know that the
# user already has python installed, so let's use python:

KG_HTTP_USER=$(python -c "import json, os; print(json.loads(os.environ['VCAP_STR'])['cluster']['user'])")
KG_HTTP_PASS=$(python -c "import json, os; print(json.loads(os.environ['VCAP_STR'])['cluster']['password'])")

KG_HTTP_URL=$(python -c "import json, os; print(json.loads(os.environ['VCAP_STR'])['cluster']['service_endpoints']['notebook_gateway'])")
KG_WS_URL=$(python -c "import json, os; print(json.loads(os.environ['VCAP_STR'])['cluster']['service_endpoints']['notebook_gateway_websocket'])")

docker run -it --rm \
	-v $(pwd)/notebooks:/tmp/notebooks \
	-e KG_HTTP_USER=$KG_HTTP_USER \
	-e KG_HTTP_PASS=$KG_HTTP_PASS \
	-e KG_URL=$KG_HTTP_URL \
	-e KG_WS_URL=$KG_WS_URL \
	-p 8888:8888 \
	biginsights/jupyter-nb-nb2kg


