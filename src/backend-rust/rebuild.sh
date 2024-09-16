#!/bin/bash

set -euo pipefail

sudo systemctl stop fibonacci-backend
cd /vagrant/src/backend-rust
cargo build
sudo cp /vagrant/src/backend-rust/target/debug/fibonacci_backend /usr/local/bin/fibonacci/

sudo systemctl start fibonacci-backend
