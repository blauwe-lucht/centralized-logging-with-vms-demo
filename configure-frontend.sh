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

echo Installing frontend...
mkdir -p /usr/local/bin/fibonacci
if [ ! -f "/usr/local/bin/fibonacci/fibonacci_server" ]; then
    cp /vagrant/src/frontend/build/fibonacci_server /usr/local/bin/fibonacci/
    cp /vagrant/src/frontend/index.html /usr/local/bin/fibonacci/
fi

echo Setting up logging...
mkdir -p /var/log/fibonacci
chown vagrant: /var/log/fibonacci

# Define service parameters
SERVICE_NAME=fibonacci-frontend
EXECUTABLE_PATH=/usr/local/bin/fibonacci/fibonacci_server
WORKING_DIRECTORY=/usr/local/bin/fibonacci/
SERVICE_USER=vagrant

echo Creating the systemd service file...
cat > /etc/systemd/system/${SERVICE_NAME}.service <<EOF
[Unit]
Description=Fibonacci Frontend Service
After=network.target

[Service]
ExecStart=${EXECUTABLE_PATH}
WorkingDirectory=${WORKING_DIRECTORY}
User=${SERVICE_USER}
Restart=on-failure
StandardOutput=append:/var/log/fibonacci/service.log
StandardError=append:/var/log/fibonacci/service.log

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload

echo Starting the frontend service...
sudo systemctl restart ${SERVICE_NAME}
sudo systemctl enable ${SERVICE_NAME}
