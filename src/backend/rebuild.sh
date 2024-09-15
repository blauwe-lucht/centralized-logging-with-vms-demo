#!/bin/bash

set -euo pipefail

# sudo systemctl stop fibonacci-backend
cd /vagrant/src/backend/build
cmake ..
make
sudo cp /vagrant/src/backend/build/fibonacci_backend /usr/local/bin/fibonacci/

# sudo systemctl start fibonacci-backend
