#!/bin/bash

instance_id=$(aws ec2 describe-instances --query "Reservations[*].Instances[*].InstanceId" --filters "Name=tag:Name,Values='Kafka Kraft Instance'" "Name=instance-state-name,Values=running" --output text)
availability_zone=$(aws ec2 describe-instances --query "Reservations[*].Instances[*].Placement.AvailabilityZone" --filters "Name=tag:Name,Values='Kafka Kraft Instance'" "Name=instance-state-name,Values=running" --output text)
public_dns_name=$(aws ec2 describe-instances --query "Reservations[*].Instances[*].PublicDnsName" --filters "Name=tag:Name,Values='Kafka Kraft Instance'" "Name=instance-state-name,Values=running" --output text)

# Generate RSA key pair
tmpfile=$(mktemp /tmp/ssh.XXXXXX)
ssh-keygen -C "eic temp key" -q -f $tmpfile -t rsa -b 2048 -N "" <<< y
public_key=${tmpfile}.pub
private_key=$tmpfile
password=$SASL_SCRAM_PASSWORD

echo 'password '$password''

# Register public key
aws ec2-instance-connect send-ssh-public-key \
  --instance-id $instance_id \
  --instance-os-user ec2-user \
  --ssh-public-key file://$public_key \
  --availability-zone $availability_zone > /dev/null

# SSH into ec2 instance with private key
ssh -i $private_key -o "StrictHostKeyChecking no" ec2-user@$public_dns_name < ./ec2-commands.sh $SASL_SCRAM_PASSWORD