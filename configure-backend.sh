#!/bin/bash

set -euo pipefail

echo "Updating system..."
yum update -y

echo "Installing necessary packages..."
yum groupinstall "Development Tools" -y
yum install cmake git boost-devel libuuid-devel nginx -y

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

echo "Opening up port 5000..."
firewall-cmd --zone=public --add-port=5000/tcp --permanent
firewall-cmd --reload

echo "Building backend..."
cd /vagrant/src/backend
mkdir -p build
cd build
cmake ..
make

echo Installing backend...
mkdir -p /usr/local/bin/fibonacci
if [ ! -f "/usr/local/bin/fibonacci/fibonacci_backend" ]; then
    cp /vagrant/src/backend/build/fibonacci_backend /usr/local/bin/fibonacci/
fi

echo Setting up logging...
mkdir -p /var/log/fibonacci
chown vagrant: /var/log/fibonacci

# Define service parameters
SERVICE_NAME=fibonacci-backend
EXECUTABLE_PATH=/usr/local/bin/fibonacci/fibonacci_backend
WORKING_DIRECTORY=/usr/local/bin/fibonacci/
SERVICE_USER=vagrant

echo Creating the systemd service file...
cat > /etc/systemd/system/${SERVICE_NAME}.service <<EOF
[Unit]
Description=Fibonacci backend Service
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

echo Starting the backend service...
sudo systemctl restart ${SERVICE_NAME}
sudo systemctl enable ${SERVICE_NAME}

echo Configuring nginx...
cat > /etc/nginx/conf.d/fibonacci_backend.conf <<EOF
server {
    listen 80;
    server_name _;
    
    location / {
        proxy_pass http://localhost:5000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
        proxy_buffer_size 128k;
        proxy_buffers 4 256k;
        proxy_busy_buffers_size 256k;
    }
}
EOF
cat > /etc/nginx/nginx.conf <<EOF
user nginx;
worker_processes auto;
error_log /var/log/nginx/error.log;
pid /run/nginx.pid;

# Load dynamic modules. See /usr/share/doc/nginx/README.dynamic.
include /usr/share/nginx/modules/*.conf;

events {
    worker_connections 1024;
}

http {
    log_format  main  '\$remote_addr - \$remote_user [\$time_local] "\$request" '
                      '\$status \$body_bytes_sent "\$http_referer" '
                      '"\$http_user_agent" "\$http_x_forwarded_for"';

    access_log  /var/log/nginx/access.log  main;

    sendfile            on;
    tcp_nopush          on;
    tcp_nodelay         on;
    keepalive_timeout   65;
    types_hash_max_size 2048;

    include             /etc/nginx/mime.types;
    default_type        application/octet-stream;

    # Load modular configuration files from the /etc/nginx/conf.d directory.
    # See http://nginx.org/en/docs/ngx_core_module.html#include
    # for more information.
    include /etc/nginx/conf.d/*.conf;
}
EOF

echo Starting nginx...
systemctl enable nginx
systemctl restart nginx

echo Opening up port 80...
firewall-cmd --permanent --add-service=http
firewall-cmd --reload

echo Allowing nginx to make network connections...
setsebool -P httpd_can_network_connect 1
