sudo yum update -y
sudo yum install -y aws-cli telnet
# Install Python and pip if not already present
dnf install -y python3 python3-pip

# Install Ansible
pip3 install ansible

# Verify installation
ansible --version
STAGE=$1
USER="ec2-user"
PUBLIC_DNS_NAMES=$(aws ec2 describe-instances --filters "Name=tag:Name,Values=*Apache*,*Kafka*" "Name=instance-state-name,Values=running" --query "Reservations[].Instances[].PrivateIP" --output text)
PRIVATE_KEY_FILE=~/ec2-keypair-$REGION-$STAGE.pem

REGION=$(aws ec2 describe-availability-zones --output text --query 'AvailabilityZones[0].[RegionName]')
echo $REGION

#STAGE=$1
PRIVATE_KEY=$(aws secretsmanager get-secret-value --secret-id "ec2-keypair-$REGION-$STAGE-private-key" --region $REGION --query SecretString --output text 2>&1)
sudo echo "$PRIVATE_KEY" > $PRIVATE_KEY_FILE
chmod 400 $PRIVATE_KEY_FILE


INSTANCE_ARRAY=($PUBLIC_DNS_NAMES)

sudo ssh -i $PRIVATE_KEY_FILE -o "StrictHostKeyChecking no" $USER@${INSTANCE_ARRAY[0]}

sudo tee inventory.ini << EOF
[kafka_nodes]
${INSTANCE_ARRAY[0]} ansible_user=$USER
${INSTANCE_ARRAY[1]} ansible_user=$USER
${INSTANCE_ARRAY[2]} ansible_user=$USER
  
[kafka_nodes:vars]
ansible_ssh_private_key_file=$PRIVATE_KEY_FILE
EOF
      
cat inventory.ini

# # Generate SSH key pair non-interactively
# ssh-keygen -t rsa -b 4096 -f ~/.ssh/kafka_ansible -q -N ""
      
# # Set proper permissions
# chmod 600 ~/.ssh/kafka_ansible
# chmod 644 ~/.ssh/kafka_ansible.pub
# chown -R ec2-user:ec2-user ~/.ssh

# Copy public key to all Kafka nodes
for host in $PUBLIC_DNS_NAMES; do
  #ssh-copy-id -i ~/.ssh/kafka_ansible.pub -o StrictHostKeyChecking=no ec2-user@$host
  echo "host: $host"
  #sudo ssh -o StrictHostKeyChecking=no $USER@$host "mkdir -p ~/.ssh && chmod 700 ~/.ssh && echo '$(cat ~/.ssh/kafka_ansible.pub)' >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys"
  sudo ssh -i $PRIVATE_KEY_FILE -o "StrictHostKeyChecking no" $USER@$host
done

ansible kafka_nodes -i inventory.ini -m shell -a --become "sudo /opt/kafka/scripts/kafka-format.sh 2>&1 | tee /tmp/kafka-format.log; sudo systemctl start kafka 2>&1 | tee /tmp/kafka-start.log; sudo systemctl status kafka --no-pager > /tmp/kafka-status.log; sudo journalctl -u kafka --since '5 min ago' --no-pager | grep -E 'error|fail|exception' > /tmp/kafka-journal-errors.log; grep -E 'ERROR|Exception' /opt/kafka/logs/server.log | tail -100 > /tmp/kafka-app-errors.log"