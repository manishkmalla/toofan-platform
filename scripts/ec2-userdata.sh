#!/bin/bash
# EC2 User Data — runs once on first boot
# Installs Docker, Docker Compose, and AWS CLI

set -e

yum update -y

# Install Docker
yum install -y docker
systemctl enable docker
systemctl start docker
usermod -aG docker ec2-user

# Install Docker Compose plugin
mkdir -p /usr/local/lib/docker/cli-plugins
curl -SL "https://github.com/docker/compose/releases/latest/download/docker-compose-linux-x86_64" \
  -o /usr/local/lib/docker/cli-plugins/docker-compose
chmod +x /usr/local/lib/docker/cli-plugins/docker-compose

# Install AWS CLI v2
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o /tmp/awscliv2.zip
cd /tmp && unzip -q awscliv2.zip && ./aws/install
rm -rf /tmp/awscliv2.zip /tmp/aws

# Create project directory
mkdir -p /home/ec2-user/toofan-platform
chown ec2-user:ec2-user /home/ec2-user/toofan-platform
