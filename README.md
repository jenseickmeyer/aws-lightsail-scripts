# Scripts for AWS Lightsail
[AWS Lightsail](https://aws.amazon.com/lightsail/) is a set of services offered by AWS which can be used to run the infrastructure needed for hosting web applications: virtual servers, managed databases and load balancers. They are similar to the standard offerings from AWS but have a smaller feature set.

Through the [AWS CLI](https://aws.amazon.com/cli/) setting up the infrastructure and automating it can be automated.

To launch an environment for hosting web applications the [launch-environment.sh](launch-environment.sh) script can be used. It creates a managed MySQL database, a load balancer and two web servers. The web servers are attached to the load balancer and run a simple [nginx](https://nginx.org) as the web server in a Docker container.
