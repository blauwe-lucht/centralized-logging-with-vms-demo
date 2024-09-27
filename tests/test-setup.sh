#!/bin/bash

set -uo pipefail

frontend_ip=192.168.6.31
backend_ip=192.168.6.32

assert() {
    local condition="$1"
    local description="$2"

    if ! eval "$condition"; then
        echo "Assertion failed: $description"
        exit 1
    fi
}

execute_remote() {
    local vm_name="$1"
    local vm_ip="$2"
    local cmd="$3"

    ssh vagrant@$vm_ip \
        -i .vagrant/machines/$vm_name/virtualbox/private_key \
        -o StrictHostKeyChecking=no \
        -o UserKnownHostsFile=/dev/null \
        -o LogLevel=ERROR \
        "sudo $cmd"
}

echo Making some calls to the frontend...
for i in {1..10}; do
    response=$(curl -s -X POST http://$frontend_ip/fibonacci -H "Content-Type: application/json" -d '{"number": 42}')
    if [[ $? -ne 0 ]]; then
        echo curl failed with exit code $?
        exit 1
    fi

    number=$(echo $response | jq '.number')
    assert "[[ $number -eq 42 ]]" "response number should be 42"

    result=$(echo $response | jq '.result')
    assert "[[ $result -eq 267914296 ]]" "response result should be 267914296"

    request_id=$(echo $response | jq -r '.request_id')
    assert "[[ -n $request_id ]]" "response request id should not be empty"
done

echo Checking frontend Nginx access logs...
execute_remote frontend $frontend_ip "grep -q '^[{]' /var/log/nginx/access.log"
assert "[[ $? -eq 0 ]]" "Nginx access log on frontend should be json format"

echo Checking backend Nginx access logs...
execute_remote backend $backend_ip "grep -q '^[{]' /var/log/nginx/access.log"
assert "[[ $? -eq 0 ]]" "Nginx access log on backend should be json format"

echo Done!
