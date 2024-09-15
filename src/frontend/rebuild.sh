#!/bin/bash

set -euo pipefail

sudo systemctl stop fibonacci-frontend
cd /vagrant/src/frontend/build
cmake ..
make
sudo cp /vagrant/src/frontend/build/fibonacci_frontend /usr/local/bin/fibonacci/

sudo systemctl start fibonacci-frontend
