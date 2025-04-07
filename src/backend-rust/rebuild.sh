#!/bin/bash

set -euo pipefail

if [ "$EUID" -ne 0 ]; then
  echo "Please run as root (cargo has only been installed for root)"
  exit 1
fi

systemctl stop fibonacci-backend
cd /vagrant/src/backend-rust
/root/.cargo/bin/cargo build
cp /vagrant/src/backend-rust/target/debug/fibonacci_backend /usr/local/bin/fibonacci/

systemctl start fibonacci-backend
