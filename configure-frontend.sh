#!/bin/bash

set -euxo pipefail

echo "Updating system..."
yum update -y

echo "Installing nginx..."
yum install -y nginx

echo "Installing Rust..."
# TODO do we still need this? yum install -y pkg-config openssl-devel
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
# Some packages are about to be deprecated, prevent that by pinning the version of the compiler.
/root/.cargo/bin/rustup install 1.81.0
/root/.cargo/bin/rustup default 1.81.0

# TODO: remove this once everything is working ok
echo "Opening up port 8080..."
firewall-cmd --zone=public --add-port=8080/tcp --permanent
firewall-cmd --reload

echo "Building frontend..."
cd /vagrant/src/frontend-rust
/root/.cargo/bin/cargo build

echo Installing frontend...
mkdir -p /usr/local/bin/fibonacci
if [ ! -f "/usr/local/bin/fibonacci/fibonacci_frontend" ]; then
    cp /vagrant/src/frontend-rust/target/debug/fibonacci_frontend /usr/local/bin/fibonacci/
    cp /vagrant/src/frontend-rust/index.html /usr/local/bin/fibonacci/
fi

echo Setting up logging...
mkdir -p /var/log/fibonacci
chown vagrant: /var/log/fibonacci

# Define service parameters
SERVICE_NAME=fibonacci-frontend
EXECUTABLE_PATH=/usr/local/bin/fibonacci/fibonacci_frontend
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

echo Configuring nginx...
cat > /etc/nginx/conf.d/fibonacci_frontend.conf <<EOF
# Create a new variable 'request_chain_id' that is either a request ID passed in
# the 'X-Request-ID' header or the request ID generated by nginx itself:
map \$http_x_request_id \$request_chain_id {
  default   "\${request_id}";
  ~*        "\${http_x_request_id}";
}

server {
    listen 80;
    server_name _;
    
    location / {
        proxy_pass http://localhost:8080;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header X-Request-ID \$request_chain_id;

        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
        proxy_buffer_size 128k;
        proxy_buffers 4 256k;
        proxy_busy_buffers_size 256k;
    }
}
EOF
if [ -f /tmp/nginx.conf ]; then
    rm -f /tmp/nginx.conf
fi
cp /vagrant/nginx/nginx.conf /tmp
chown root: /tmp/nginx.conf /tmp/nginx.conf
mv /tmp/nginx.conf /etc/nginx/nginx.conf

echo Starting nginx...
systemctl enable nginx
systemctl restart nginx

echo Opening up port 80...
firewall-cmd --permanent --add-service=http
firewall-cmd --reload

echo Allowing nginx to make network connections...
setsebool -P httpd_can_network_connect 1

echo Installing fluentbit...
curl https://raw.githubusercontent.com/fluent/fluent-bit/master/install.sh | sh

echo Configuring fluentbit...
mkdir -p /var/lib/fluent-bit
if [ -f /tmp/fluent-bit.conf ]; then
    rm -f /tmp/fluent-bit.conf
fi
cp /vagrant/fluent-bit/frontend/fluent-bit.conf /tmp
cp /vagrant/fluent-bit/parsers.conf /tmp
chown root: /tmp/fluent-bit.conf /tmp/parsers.conf
mv /tmp/fluent-bit.conf /etc/fluent-bit/fluent-bit.conf
mv /tmp/parsers.conf /etc/fluent-bit/parsers.conf

echo Starting fluentbit...
systemctl enable fluent-bit
systemctl restart fluent-bit
