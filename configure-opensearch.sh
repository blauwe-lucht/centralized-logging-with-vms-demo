#!/bin/bash

set -euo pipefail

opensearch_auth='admin:T!mberW0lf#92'
opensearch_url="https://localhost:9200"
osd_api=http://localhost:5601/api

echo Installing docker...
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y apt-transport-https ca-certificates curl software-properties-common
if [ ! -f /etc/apt/sources.list.d/docker.list ]; then
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
fi
apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

echo Configuring system for OpenSearch...
swapoff -a
if grep -q "vm.max_map_count" /etc/sysctl.conf; then
    sed -i 's/^vm.max_map_count.*/vm.max_map_count=262144/' /etc/sysctl.conf
else
    echo "vm.max_map_count=262144" >> /etc/sysctl.conf
fi
sysctl -p

echo Starting OpenSearch...
docker compose -f /vagrant/opensearch/docker-compose.yml up -d --quiet-pull

echo Configuring OpenSearch...
# This will create an index template that will change the default precision
# of @timestamp from milliseconds to nanoseconds. We need this to have all
# our events displayed in the correct order.
curl -s -X PUT "$opensearch_url/_index_template/fibonacci_template" \
    -H "Content-Type: application/json" \
    -u "$opensearch_auth" \
    --insecure \
    -d '{
  "index_patterns": ["fibonacci-*"],
  "template": {
    "mappings": {
      "properties": {
        "@timestamp": {
          "type": "date_nanos",
          "format": "strict_date_optional_time_nanos"
        }
      }
    }
  }
}'
echo

echo "Waiting for OpenSearch Dashboards to get ready..."
max_retries=30
retry_interval=2
url="$osd_api/saved_objects/index-pattern/fibonacci"
for ((i=1; i<=max_retries; i++)); do
    set +e
    response=$(curl -s -X GET "$url" -u "$opensearch_auth" -H 'osd-xsrf: true')
    curl_exit=$?
    set -e

    if [[ $curl_exit -eq 0 && "$response" != *"not ready yet"* ]]; then
        echo "Got response:"
        echo "$response"
        break
    fi

    echo "No valid response yet (exit=$curl_exit, response=$response). Sleeping $retry_interval seconds..."
    sleep $retry_interval
done

echo Configuring OpenSearch Dashboards...
# Create an index pattern that we can use in the Discover page:
curl -s -X POST "$osd_api/saved_objects/index-pattern/fibonacci" \
    -u "$opensearch_auth" \
    -H "Content-Type: application/json" \
    -H "osd-xsrf: true" \
    -d '{
    "attributes": {
        "title": "fibonacci*",
        "timeFieldName": "@timestamp"
    }
}'

echo
echo Done!
