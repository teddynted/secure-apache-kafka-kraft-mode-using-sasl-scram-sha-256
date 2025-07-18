#!/bin/bash

instance_id=$(aws ec2 describe-instances --query "Reservations[*].Instances[*].InstanceId" --filters "Name=tag:Name,Values='Apache Kafka Kraft Instance 1'" "Name=instance-state-name,Values=running" --output text)
availability_zone=$(aws ec2 describe-instances --query "Reservations[*].Instances[*].Placement.AvailabilityZone" --filters "Name=tag:Name,Values='Apache Kafka Kraft Instance 1'" "Name=instance-state-name,Values=running" --output text)
public_dns_name=$(aws ec2 describe-instances --query "Reservations[*].Instances[*].PublicDnsName" --filters "Name=tag:Name,Values='Apache Kafka Kraft Instance 1'" "Name=instance-state-name,Values=running" --output text)
private_dns_name=$(aws ec2 describe-instances --query "Reservations[*].Instances[*].PrivateDnsName" --filters "Name=tag:Name,Values='Apache Kafka Kraft Instance 1'" "Name=instance-state-name,Values=running" --output text)
public_ip_address=$(aws ec2 describe-instances --query "Reservations[*].Instances[*].PublicIpAddress" --filters "Name=tag:Name,Values='Apache Kafka Kraft Instance 1'" "Name=instance-state-name,Values=running" --output text)
private_dns_name_node_2=$(aws ec2 describe-instances --query "Reservations[*].Instances[*].PrivateDnsName" --filters "Name=tag:Name,Values='Apache Kafka Kraft Instance 2'" "Name=instance-state-name,Values=running" --output text)
private_dns_name_node_3=$(aws ec2 describe-instances --query "Reservations[*].Instances[*].PrivateDnsName" --filters "Name=tag:Name,Values='Apache Kafka Kraft Instance 3'" "Name=instance-state-name,Values=running" --output text)

# Generate RSA key pair
tmpfile=$(mktemp /tmp/ssh.XXXXXX)
ssh-keygen -C "eic temp key" -q -f $tmpfile -t rsa -b 2048 -N "" <<< y
public_key=${tmpfile}.pub
private_key=$tmpfile
password=$SASL_SCRAM_PASSWORD
username=$SASL_SCRAM_USERNAME

# Register public key
aws ec2-instance-connect send-ssh-public-key \
  --instance-id $instance_id \
  --instance-os-user ec2-user \
  --ssh-public-key file://$public_key \
  --availability-zone $availability_zone > /dev/null

VOTERS="controller.quorum.voters=1@$private_dns_name:9094,2@$private_dns_name_node_2:9094,3@$private_dns_name_node_3:9094"

# SSH into ec2 instance with private key
ssh -i $private_key -o "StrictHostKeyChecking no" ec2-user@$public_dns_name "bash -s" < ./shell-scripts/kafka-service.sh $private_dns_name $public_ip_address $NODE_ID $VOTERS