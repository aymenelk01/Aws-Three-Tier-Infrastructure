#!/bin/bash

# Install SSM Agent manually
dnf install -y amazon-ssm-agent

# Enable and start SSM Agent
systemctl enable amazon-ssm-agent
systemctl start amazon-ssm-agent

# Update packages
dnf update -y

# Install nginx
dnf install -y nginx
systemctl start nginx
systemctl enable nginx

# Check SSM status after install
systemctl status amazon-ssm-agent > /tmp/ssm-status.txt 2>&1
cp /tmp/ssm-status.txt /usr/share/nginx/html/ssm.txt

# Fetch instance ID
TOKEN=$(curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
INSTANCE_ID=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" -s http://169.254.169.254/latest/meta-data/instance-id)

echo "<h1>Welcome to Aymen's Cloud App</h1>" > /usr/share/nginx/html/index.html
echo "<p>This request is being served by EC2 Instance ID: <b>$INSTANCE_ID</b></p>" >> /usr/share/nginx/html/index.html