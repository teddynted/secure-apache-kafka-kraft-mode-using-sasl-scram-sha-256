sudo yum update -y
sudo yum install -y aws-cli telnet
# Install Python and pip if not already present
dnf install -y python3 python3-pip

# Install Ansible
pip3 install ansible

# Verify installation
ansible --version

USER="ec2-user"
PUBLIC_DNS_NAMES=$(aws ec2 describe-instances --filters "Name=tag:Name,Values=*Apache*,*Kafka*" "Name=instance-state-name,Values=running" --query "Reservations[].Instances[].PublicDnsName" --output text)

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

echo "PUBLIC_DNS_NAMES: $PUBLIC_DNS_NAMES"

# Generate SSH key pair non-interactively
ssh-keygen -t rsa -b 4096 -f ~/.ssh/kafka_ansible -q -N ""
      
# Set proper permissions
chmod 600 ~/.ssh/kafka_ansible
chmod 644 ~/.ssh/kafka_ansible.pub
chown -R ec2-user:ec2-user ~/.ssh
# Copy public key to all Kafka nodes
for host in $PUBLIC_DNS_NAMES; do
  #ssh-copy-id -i ~/.ssh/kafka_ansible.pub -o StrictHostKeyChecking=no ec2-user@$host
  echo "host: $host"
  sudo ssh -o StrictHostKeyChecking=no $USER@$host "mkdir -p ~/.ssh && chmod 700 ~/.ssh && echo '$(cat ~/.ssh/kafka_ansible.pub)' >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys"
done

ansible kafka_nodes -i inventory.ini -m shell -a --become "sudo /opt/kafka/scripts/kafka-format.sh 2>&1 | tee /tmp/kafka-format.log; sudo systemctl start kafka 2>&1 | tee /tmp/kafka-start.log; sudo systemctl status kafka --no-pager > /tmp/kafka-status.log; sudo journalctl -u kafka --since '5 min ago' --no-pager | grep -E 'error|fail|exception' > /tmp/kafka-journal-errors.log; grep -E 'ERROR|Exception' /opt/kafka/logs/server.log | tail -100 > /tmp/kafka-app-errors.log"