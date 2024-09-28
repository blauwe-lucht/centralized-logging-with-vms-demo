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

echo Configuring OpenSearch Dashboards...
# Create an index pattern that we can use in the Discover page:
response=$(curl -s -X GET "$osd_api/saved_objects/index-pattern/fibonacci" \
  -u "$opensearch_auth" \
  -H "osd-xsrf: true" || true)
if echo "$response" | grep -q '"statusCode":404'; then
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
fi

echo
echo Done!
