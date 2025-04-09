#!/bin/bash

set -ueo pipefail

for vm in frontend backend opensearch; do
    echo "$vm:"
    vagrant ssh "$vm" -c "sudo timedatectl set-ntp false && sudo timedatectl set-ntp true && sleep 1 && date"
done
