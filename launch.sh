#!/bin/bash

# Install security updates
yum -y --security update

# Mount shared file system
yum -y install amazon-efs-utils
mkdir /mnt/efs
sudo mount -t nfs4 \
           -o nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2 \
           172.31.14.222:/ /mnt/efs

# Install CodeDeploy Agent
yum -y install ruby
yum -y install wget
cd /home/ec2-user
wget https://aws-codedeploy-eu-central-1.s3.amazonaws.com/latest/install
chmod +x ./install
./install auto
rm ./install

cat <<EOF > /etc/codedeploy-agent/conf/codedeploy.onpremises.yml
---
aws_access_key_id: <ACCESS_KEY>
aws_secret_access_key: <SECRET_ACCESS_KEY>
iam_user_arn: <IAM_USER_ARN>
region: <AWS_REGION>
EOF

service codedeploy-agent restart

# Install Docker
yum -y install docker
service docker start
usermod -a -G docker ec2-user

# Install Docker Compose
curl -L "https://github.com/docker/compose/releases/download/1.24.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# Launch demo container
docker run --name nginx --rm -p 80:80 -d nginx
