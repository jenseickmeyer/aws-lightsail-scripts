#!/bin/bash

# Install security updates
yum -y --security update

# Install Docker
yum -y install docker
service docker start
usermod -a -G docker ec2-user

# Install Docker Compose
curl -L "https://github.com/docker/compose/releases/download/1.24.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# Launch demo container
docker run --name nginx --rm -p 80:80 -d nginx
