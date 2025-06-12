#!/bin/bash

instance_ids=$(aws ec2 describe-instances --filters "Name=tag:Name,Values=*kafka*" --query "Reservations[*].Instances[*].[PrivateIpAddress]" --output text)
echo "suffer $instance_id"
sudo touch kafka-hosts.txt

# sudo cat <<EOF > kafka-hosts.txt
# echo $instance_id
# EOF

sudo echo "Dog $instance_id" > kafka-hosts.txt

# cat <<EOF > kafka-hosts.txt
# $instance_id
# node.id=1
# process.roles=broker,controller
# controller.quorum.voters=1@node1:9093,2@node2:9093,3@node3:9093
# listeners=PLAINTEXT://:9092,CONTROLLER://:9093
# log.dirs=/tmp/kraft-logs
# EOF