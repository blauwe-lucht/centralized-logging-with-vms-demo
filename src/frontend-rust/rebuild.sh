#!/bin/bash

set -euo pipefail

sudo systemctl stop fibonacci-frontend
cd /vagrant/src/frontend-rust
cargo build
sudo cp /vagrant/src/frontend-rust/target/debug/fibonacci_frontend /usr/local/bin/fibonacci/

sudo systemctl start fibonacci-frontend
