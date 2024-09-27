#!/bin/bash

set -euo pipefail

echo "Updating system..."
yum update -y

echo "Installing nginx..."
yum install -y nginx

echo "Installing Rust..."
yum install -y pkg-config openssl-devel
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
# Some packages are about to be deprecated, prevent that by pinning the version of the compiler.
/root/.cargo/bin/rustup install 1.81.0
/root/.cargo/bin/rustup default 1.81.0

echo "Opening up port 5000..."
firewall-cmd --zone=public --add-port=5000/tcp --permanent
firewall-cmd --reload

echo "Building backend..."
cd /vagrant/src/backend-rust
/root/.cargo/bin/cargo build

echo Installing backend...
mkdir -p /usr/local/bin/fibonacci
if [ ! -f "/usr/local/bin/fibonacci/fibonacci_backend" ]; then
    cp /vagrant/src/backend-rust/target/debug/fibonacci_backend /usr/local/bin/fibonacci/
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
map \$http_x_request_id \$request_chain_id {
  default   "\${request_id}";
  ~*        "\${http_x_request_id}";
}

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

echo Installing fluentbit...
curl https://raw.githubusercontent.com/fluent/fluent-bit/master/install.sh | sh

echo Configuring fluentbit...
mkdir -p /var/lib/fluent-bit
if [ -f /tmp/fluent-bit.conf ]; then
    rm -f /tmp/fluent-bit.conf
fi
cp /vagrant/fluent-bit/backend/fluent-bit.conf /tmp
cp /vagrant/fluent-bit/parsers.conf /tmp
chown root: /tmp/fluent-bit.conf /tmp/parsers.conf
mv /tmp/fluent-bit.conf /etc/fluent-bit/fluent-bit.conf
mv /tmp/parsers.conf /etc/fluent-bit/parsers.conf

echo Starting fluentbit...
systemctl enable fluent-bit
systemctl restart fluent-bit
