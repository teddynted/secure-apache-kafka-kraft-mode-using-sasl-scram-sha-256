sudo yum update -y
sudo yum install -y aws-cli
# Install Python and pip if not already present
sudo dnf install -y python3 python3-pip

# Install Ansible
sudo pip3 install ansible

# Verify installation
ansible --version

PRIVATE_IPS=$(aws ec2 describe-instances --filters "Name=tag:Name,Values=*Apache*,*Kafka*" "Name=instance-state-name,Values=running" --query "Reservations[].Instances[].PrivateIpAddress" --output text)
# Get IPs
FIRST_IP=${IP_ARRAY[0]}
SECOND_IP=${IP_ARRAY[1]}
THIRD_IP=${IP_ARRAY[2]}

# Generate SSH key pair non-interactively
ssh-keygen -t rsa -b 4096 -f ~/.ssh/kafka_ansible -q -N ""
      
# Set proper permissions
chmod 600 ~/.ssh/kafka_ansible
chmod 644 ~/.ssh/kafka_ansible.pub
chown -R ec2-user:ec2-user ~/.ssh
# Copy public key to all Kafka nodes
for host in $PRIVATE_IPS; do
  #ssh-copy-id -i ~/.ssh/kafka_ansible.pub -o StrictHostKeyChecking=no ec2-user@$host
  ssh -o StrictHostKeyChecking=no ec2-user@$host "mkdir -p ~/.ssh && chmod 700 ~/.ssh && echo '$(cat ~/.ssh/kafka_ansible.pub)' >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys"
done
      
# Test SSH connection
echo "Testing SSH connection"
ssh -i ~/.ssh/kafka_ansible ec2-user@FIRST_IP
# Convert space-separated list into array
read -ra IP_ARRAY <<< "$PRIVATE_IPS"
      
# Sort the IPs (optional, for deterministic order)
IFS=$'\n' IP_ARRAY=($(sort <<<"${IP_ARRAY[*]}"))
unset IFS

sudo tee inventory.ini << EOF
[kafka_nodes]
$FIRST_IP
$SECOND_IP
$THIRD_IP
  
[kafka_nodes:vars]
ansible_user=ec2-user
ansible_ssh_private_key_file=~/.ssh/kafka_ansible
EOF
      
cat inventory.ini

ansible kafka_nodes -i inventory.ini -m shell -a "sudo /opt/kafka/scripts/kafka-format.sh 2>&1 | tee /tmp/kafka-format.log; sudo systemctl start kafka 2>&1 | tee /tmp/kafka-start.log; sudo systemctl status kafka --no-pager > /tmp/kafka-status.log; sudo journalctl -u kafka --since '5 min ago' --no-pager | grep -E 'error|fail|exception' > /tmp/kafka-journal-errors.log; grep -E 'ERROR|Exception' /opt/kafka/logs/server.log | tail -100 > /tmp/kafka-app-errors.log" \ --become