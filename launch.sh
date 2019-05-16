#!/bin/bash

# Install security updates
yum -y --security update

# Mount shared file system
yum -y install amazon-efs-utils
mkdir /mnt/efs
sudo mount -t nfs4 \
           -o nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2 \
           172.31.14.222:/ /mnt/efs

# Install Docker
yum -y install docker
service docker start
usermod -a -G docker ec2-user

# Install Docker Compose
curl -L "https://github.com/docker/compose/releases/download/1.24.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# Launch demo container
docker run --name nginx --rm -p 80:80 -d nginx
