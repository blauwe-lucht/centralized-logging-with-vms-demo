#!/bin/bash

set -euo pipefail

if [ "$EUID" -ne 0 ]; then
  echo "Please run as root (cargo has only been installed for root)"
  exit 1
fi

systemctl stop fibonacci-frontend
cd /vagrant/src/frontend-rust
/root/.cargo/bin/cargo build
cp /vagrant/src/frontend-rust/target/debug/fibonacci_frontend /usr/local/bin/fibonacci/

systemctl start fibonacci-frontend
