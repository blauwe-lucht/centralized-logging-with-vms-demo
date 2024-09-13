#!/bin/bash

set -euo pipefail

echo "Updating system..."
yum update -y

echo "Installing necessary packages..."
yum groupinstall "Development Tools" -y
yum install cmake git boost-devel libuuid-devel -y

echo "Cloning Crow repository..."
if [ ! -d "/usr/local/include/crow" ]; then
    git clone https://github.com/CrowCpp/crow.git /usr/local/include/crow
fi

echo "Installing spdlog..."
if [ ! -d "/usr/local/include/spdlog" ]; then
    git clone https://github.com/gabime/spdlog.git /usr/local/include/spdlog
fi

echo "Installing asio..."
if [ ! -d "/usr/local/include/asio" ]; then
    git clone https://github.com/chriskohlhoff/asio /usr/local/include/asio
fi

echo "Opening up port 8080..."
firewall-cmd --zone=public --add-port=8080/tcp --permanent
firewall-cmd --reload

echo "Building frontend..."
cd /vagrant/src/frontend
mkdir -p build
cd build
cmake ..
make

echo "Frontend executable is available at /vagrant/src/frontend/build/fibonacci_server"
