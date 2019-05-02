#!/usr/bin/env bash

REGION="eu-central-1"
STAGE="dev"
DOMAIN="example.com"

function get_instance_state () {
  local state=$(aws lightsail get-instance-state --instance-name $1 \
                                                 --query state.name \
                                                 --output text)
  echo $state
}

function wait_for_instance_to_run () {
  local state=$(get_instance_state $1)

  while [ $state != "running" ]
  do
    echo "Waiting for instance $1 to start up..."
    sleep 10

    state=$(get_instance_state $1)
  done
}

function get_load_balancer_state () {
  local state=$(aws lightsail get-load-balancer --load-balancer-name $1 \
                                                 --query "loadBalancer.state" \
                                                 --output text)
  echo $state
}

function wait_for_load_balancer_to_become_active () {
  local state=$(get_load_balancer_state $1)

  while [ $state != "active" ]
  do
    echo "Waiting for load balancer to become active..."
    sleep 10

    state=$(get_load_balancer_state $1)
  done
}

function get_certificate_state () {
  local state=$(aws lightsail get-load-balancer-tls-certificates --load-balancer-name $1 \
                                                                 --query "tlsCertificates[0].status" \
                                                                 --output text)
  echo $state
}

function wait_for_certificate_state () {
  local state=$(get_certificate_state $1)
  echo $state

  while [ $state != $2 ]
  do
    echo "Waiting for certificate to become $2..."
    sleep 10

    state=$(get_certificate_state $1)
    echo $state
  done
}

function get_instance_health () {
  local state=$(aws lightsail get-load-balancer --load-balancer-name $1 \
                                                --query "loadBalancer.instanceHealthSummary[?instanceName=='${2}'].instanceHealth" \
                                                --output text)
  echo $state
}

function wait_for_instance_to_become_healthy () {
  local state=$(get_instance_health $1 $2)

  while [ $state != "healthy" ]
  do
    echo "Waiting for instance $2 to become healthy..."
    sleep 10

    state=$(get_instance_health $1 $2)
  done
}

function get_database_state () {
  local state=$(aws lightsail get-relational-database --relational-database-name $1 \
                                                      --query "relationalDatabase.state" \
                                                      --output text)
  echo $state
}

function wait_for_database_to_become_available () {
  local state=$(get_database_state $1)

  while [ $state != "available" ]
  do
    echo "Waiting for database to become available..."
    sleep 10

    state=$(get_database_state $1)
  done
}

# Create a database instance
echo "Creating database instance..."
aws lightsail create-relational-database --relational-database-name "example-db" \
                                         --availability-zone "${REGION}b" \
                                         --relational-database-blueprint-id "mysql_5_7" \
                                         --relational-database-bundle-id "micro_1_0" \
                                         --master-database-name "example" \
                                         --master-username "example" \
                                         --tags "key=stage,value=$STAGE" \
                                         --no-publicly-accessible > /dev/null

# Create a load balancer
echo "Creating load balancer..."
aws lightsail create-load-balancer --load-balancer-name "example-load-balancer" \
                                   --instance-port 80 \
                                   --tags "key=stage,value=$STAGE" > /dev/null

wait_for_load_balancer_to_become_active "example-load-balancer"

echo "Load balancer is active"

# # Create a SSL certificate
echo "Request SSL certificate for load balancer"
aws lightsail create-load-balancer-tls-certificate --load-balancer-name "example-load-balancer" \
                                                   --certificate-name "example-certificate" \
                                                   --certificate-domain-name "www.${DOMAIN}" \
                                                   --tags "key=stage,value=$STAGE" > /dev/null

# Create DNS record for load balancer
echo "Creating DNS record for load balancer"
dnsName=$(aws lightsail get-load-balancer --load-balancer-name "example-load-balancer" \
                                          --query "loadBalancer.dnsName" \
                                          --output text)

aws lightsail create-domain-entry --domain-name $DOMAIN \
                                  --domain-entry "name=www.${DOMAIN},target=$dnsName,isAlias=true,type=A" \
                                  --region "us-east-1" > /dev/null

wait_for_certificate_state "example-load-balancer" "PENDING_VALIDATION"

read -r name value <<< $(aws lightsail get-load-balancer-tls-certificates --load-balancer-name "example-load-balancer" \
                                                                          --query "tlsCertificates[0].domainValidationRecords[0].[name,value]" \
                                                                          --output text)

echo "Create DNS records for certificate validation..."
aws lightsail create-domain-entry --domain-name $DOMAIN \
                                  --domain-entry "name=$name,target=$value,type=CNAME" \
                                  --region "us-east-1" > /dev/null

wait_for_certificate_state "example-load-balancer" "ISSUED"

echo "Attaching SSL certificate to load balancer"
aws lightsail attach-load-balancer-tls-certificate --load-balancer-name "example-load-balancer" \
                                                   --certificate-name "example-certificate" > /dev/null

wait_for_database_to_become_available "example-db"

# # Create web server instances
echo "Starting web servers..."
aws lightsail create-instances --instance-names "example-web-server-a" \
                               --availability-zone "${REGION}a" \
                               --bundle-id "nano_2_0" \
                               --blueprint-id "amazon_linux_2018_03_0_3" \
                               --user-data file://launch.sh \
                               --tags "key=stage,value=$STAGE" > /dev/null

aws lightsail create-instances --instance-names "example-web-server-b" \
                               --availability-zone "${REGION}b" \
                               --bundle-id "nano_2_0" \
                               --blueprint-id "amazon_linux_2018_03_0_3" \
                               --user-data file://launch.sh \
                               --tags "key=stage,value=$STAGE" > /dev/null

wait_for_instance_to_run "example-web-server-a"
wait_for_instance_to_run "example-web-server-b"

# Open only SSH port for web server instances
echo "Closing HTTP port"
aws lightsail put-instance-public-ports --instance-name "example-web-server-a" \
                                        --port-infos "fromPort=22,toPort=22,protocol=tcp" > /dev/null
aws lightsail put-instance-public-ports --instance-name "example-web-server-b" \
                                        --port-infos "fromPort=22,toPort=22,protocol=tcp" > /dev/null

# Attach web servers to load balancer
echo "Attaching web servers to load balancer..."
aws lightsail attach-instances-to-load-balancer --load-balancer-name "example-load-balancer" \
                                                --instance-names "example-web-server-a" "example-web-server-b" > /dev/null

wait_for_instance_to_become_healthy "example-load-balancer" "example-web-server-a"
wait_for_instance_to_become_healthy "example-load-balancer" "example-web-server-b"

echo "Web servers are attached to load balancer and receive traffic"

open http://$DOMAIN
