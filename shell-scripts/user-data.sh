#!/bin/bash -u

set -euxo pipefail

sudo yum update -y
sudo yum install -y java-11-amazon-corretto aws-cli jq firewalld telnet chrony
sudo systemctl enable --now firewalld
export JAVA_HOME=/usr/lib/jvm/java-11-amazon-corretto
export PATH=$PATH:$JAVA_HOME/bin
wget https://downloads.apache.org/kafka/3.9.0/kafka_2.12-3.9.0.tgz
tar xzf kafka_2.12-3.9.0.tgz
sudo mv -f kafka_2.12-3.9.0 /opt
sudo ln -s kafka_2.12-3.9.0 /opt/kafka
sudo chown ec2-user:ec2-user /opt/kafka && sudo chmod u+s /opt/kafka
ls -l 
ls -l /opt/kafka/

# Generate TLS Certificate and Stores
CA_DIR=/opt/kafka/config/kafka-ssl
S3_BUCKET_NAME=kafka-certs-bucket-develop
REGION=$(aws ec2 describe-availability-zones --output text --query 'AvailabilityZones[0].[RegionName]')
NODE=`hostname -f`
NODE_ID=$1
VALIDITY_DAYS=3650
COUNTRY="ZA"
STATE="Gauteng"
ORGANIZATION_UNIT="IT"
CITY=Johannesburg
ORGANIZATION="Pixventive"
CA_CRT=""
CA_KEY=""
HOME_DIR="../../../../../"

SECRET_JSON=$(aws secretsmanager get-secret-value --secret-id "KafkaBrokerSaslScram256" --region "$REGION" --query SecretString --output text)
echo "SECRET_JSON $SECRET_JSON"
PASSWORD=$(echo "$SECRET_JSON" | jq -r .password)
USERNAME=$(echo "$SECRET_JSON" | jq -r .username)

sudo mkdir $CA_DIR
sudo mkdir "$CA_DIR/kafka-certs"
sudo mkdir "$CA_DIR/kafka-certs/node-$NODE_ID"

ls

# Could not find CA certificate from 
# Check if a Certificate Authority exists in an s3 bucket
if aws s3 ls "s3://${S3_BUCKET_NAME}/kafka-ca/" > /dev/null 2>&1; then
  echo "Reuse existing CA from S3"
  # Download an existing ca from an S3 bucket
  sudo mkdir -p "$CA_DIR/ca"
  cd "$CA_DIR/ca"
  aws s3 cp s3://kafka-certs-bucket-develop/kafka-ca/ca.crt .
  aws s3 cp s3://kafka-certs-bucket-develop/kafka-ca/ca.key .
  CA_CRT="$CA_DIR/ca/ca.crt"
  CA_KEY="$CA_DIR/ca/ca.key"
  # Fix permissions
  sudo chmod -R 600 $CA_CRT
  sudo chmod -R 644 $CA_KEY
  sudo chown ec2-user:ec2-user $CA_CRT
  sudo chown ec2-user:ec2-user $CA_KEY
  cat $CA_CRT
  cat $CA_KEY
  ls
  # Check if file exists and is not empty
  if [[ -s ${CA_CRT} ]]; then
    echo "✅ File downloaded and contains content."
  else
    echo "❌ File is empty or failed to download."
    exit 1
  fi
  if [[ -s ${CA_KEY} ]]; then
    echo "✅ File downloaded and contains content."
  else
    echo "❌ File is empty or failed to download."
    exit 1
  fi
  echo "Checking signature algorithm"
  sudo openssl x509 -in $CA_CRT -noout -text | grep "Signature Algorithm"
  sleep 3
else
  # Generate a common Certificate Authority for muliple Apache Kafka Cluster Nodes
  # And upload it to an S3 bucket
  echo "Generating a new common CA"
  sudo mkdir -p "$CA_DIR/ca"
  cd "$CA_DIR/ca"
  sudo openssl genrsa -aes256 -passout pass:$PASSWORD -out ca.key 4096
  sudo openssl req -x509 -new -nodes -key ca.key -sha256 -days $VALIDITY_DAYS -out ca.crt -passin pass:$PASSWORD -subj "/C=$COUNTRY/ST=$STATE/L=$CITY/O=$ORGANIZATION/OU=$ORGANIZATION_UNIT/CN=KafkaCA"
  aws s3 cp "$CA_DIR/ca/" s3://${S3_BUCKET_NAME}/kafka-ca/ --recursive --region $REGION
  CA_CRT="$CA_DIR/ca/ca.crt"
  CA_KEY="$CA_DIR/ca/ca.key"
  echo "Checking signature algorithm"
  sudo openssl x509 -in /opt/kafka/config/kafka-ssl/ca/ca.crt -noout -text
  sleep 3
fi

cd $HOME_DIR
ls

echo "CA_CRT $CA_CRT"
echo "CA_KEY $CA_KEY"

cd "$CA_DIR/kafka-certs/node-$NODE_ID"

# Generate private key
sudo openssl genrsa -out $NODE.key 2048

# Create CSR
sudo openssl req -new -key $NODE.key -out $NODE.csr -subj "/C=$COUNTRY/ST=$STATE/L=$CITY/O=$ORGANIZATION/OU=$ORGANIZATION_UNIT/CN=$NODE"

sudo touch ext.cnf
# Create ext file for SAN
sudo cat > ext.cnf <<EOF
subjectAltName = DNS:$NODE
EOF

# Sign certificate with CA
sudo openssl x509 -req -in $NODE.csr -CA $CA_CRT -CAkey $CA_KEY -CAcreateserial -out $NODE.crt -days 365 -sha256 -extfile ext.cnf -passin pass:$PASSWORD

# Generate Truststore and Keystore with JKS
# Convert .crt and .key to PKCS12
sudo openssl pkcs12 -export -in $NODE.crt -inkey $NODE.key -certfile $CA_CRT -out $NODE.p12 -name $NODE -password pass:$PASSWORD

# Import into Java Keystore
sudo keytool -importkeystore -destkeystore $NODE.keystore.jks -srckeystore $NODE.p12 -srcstoretype PKCS12 -alias $NODE -storepass $PASSWORD -srcstorepass $PASSWORD

# Create truststore
sudo keytool -import -trustcacerts -alias CARoot -file $CA_CRT -keystore truststore.jks -storepass $PASSWORD -noprompt

# Delete existing files from previous uploads
aws s3 rm s3://${S3_BUCKET_NAME}/kafka-certs/node-$NODE_ID --recursive

# Upload certs so to S3 bucket
aws s3 cp "$CA_DIR/kafka-certs/node-$NODE_ID/" s3://${S3_BUCKET_NAME}/kafka-certs/node-$NODE_ID/ --recursive --region $REGION

chmod 644 "$CA_DIR/kafka-certs/node-$NODE_ID/truststore.jks"
chown ec2-user:ec2-user "$CA_DIR/kafka-certs/node-$NODE_ID/truststore.jks"

cd $HOME_DIR
ls

sudo mkdir -p /var/lib/kafka/logs
sudo chmod -R 700 /var/lib/kafka
sudo chown -R ec2-user:ec2-user /var/lib/kafka
sudo sed -i s/node.id=1/node.id=$NODE_ID/ /opt/kafka/config/kraft/server.properties
sudo sed -i s/num.partitions=1/num.partitions=3/ /opt/kafka/config/kraft/server.properties
sudo sed -i s/log.dirs=\\/tmp\\/kraft-combined-logs/log.dirs=\\/opt\\/kafka\\/config\\/kraft\\/kraft-combined-logs/ /opt/kafka/config/kraft/server.properties
sudo sed -i s/inter.broker.listener.name=PLAINTEXT/inter.broker.listener.name=INTERNAL/ /opt/kafka/config/kraft/server.properties
sudo sh -c 'cat << EOF >> /opt/kafka/config/kraft/server.properties
sasl.enabled.mechanisms=SCRAM-SHA-256
sasl.mechanism.controller.protocol=SCRAM-SHA-256
sasl.mechanism.inter.broker.protocol=SCRAM-SHA-256
# ssl.client.auth=required
ssl.protocol=TLS
ssl.cipher.suites=TLS_ECDHE_ECDSA_WITH_AES_256_GCM_SHA384,TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384
ssl.enabled.protocols=TLSv1.2,TLSv1.1,TLSv1
ssl.truststore.location=/opt/kafka/config/kafka-ssl/kafka-certs/node-'$NODE_ID'/truststore.jks
ssl.truststore.type=PKCS12
ssl.truststore.password='$PASSWORD'
ssl.keystore.location=/opt/kafka/config/kafka-ssl/kafka-certs/node-'$NODE_ID'/'$NODE'.keystore.jks
ssl.keystore.type=PKCS12
ssl.keystore.password='$PASSWORD'
ssl.key.password='$PASSWORD'
ssl.endpoint.identification.algorithm=
group.initial.rebalance.delay.ms=3000
group.min.session.timeout.ms=6000
group.max.session.timeout.ms=300000
partition.assignment.strategy=cooperative-sticky
offsets.topic.num.partitions=50 
offsets.topic.replication.factor=3
session.timeout.ms=45000
heartbeat.interval.ms=15000
max.poll.interval.ms=300000
authorizer.class.name=org.apache.kafka.metadata.authorizer.StandardAuthorizer
allow.everyone.if.no.acl.found=true
super.users=User:admin
delete.topic.enable=true
default.replication.factor=3
min.insync.replicas=2
auto.create.topics.enable=true
unclean.leader.election.enable=false
controller.quorum.append.linger.ms=500
controller.quorum.election.timeout.ms=2000
num.replica.alter.log.dirs.threads=4
connections.max.idle.ms=600000
socket.connection.setup.timeout.ms=30000
socket.connection.setup.timeout.max.ms=30000
# Increase connection timeout
request.timeout.ms=30000
# Increase raft timeouts
raft.election.timeout.ms=2000
raft.fetch.timeout.ms=2000
log.retention.hours=1
log.segment.bytes=10485760
EOF'

# # t2.medium
# echo 'export KAFKA_HEAP_OPTS="-Xms1G -Xmx1G"' >> /etc/environment
# # t2.micro
# #echo 'export KAFKA_HEAP_OPTS="-Xmx512M -Xms256M"' >> /etc/environment
# echo 'export KAFKA_OPTS="-Djava.security.auth.login.config=/opt/kafka/config/kraft/jaas.conf"' >> /etc/environment
# echo 'export KAFKA_JVM_PERFORMANCE_OPTS="-XX:+UseG1GC -XX:MaxGCPauseMillis=20 -XX:InitiatingHeapOccupancyPercent=35 -XX:+ExplicitGCInvokesConcurrent"' >> /etc/environment
# # Debugging errors
# echo 'KAFKA_LOG4J_OPTS="-Dlog4j.configuration=file:/opt/kafka/config/kraft/log4j.properties"' >> /etc/environment
# # Create Kafka service
# sudo cat <<EOF > /etc/systemd/system/kafka.service
# [Unit]
# Description=Kafka Service
# After=network-online.target
# Requires=network-online.target
 
# [Service]
# Type=simple
# User=ec2-user
# Restart=on-failure
# SyslogIdentifier=kafka
# #Environment="KAFKA_HEAP_OPTS='-Xms1G -Xmx1G'"
# Environment="KAFKA_HEAP_OPTS='-Xmx384m -Xms384m'"
# #Environment="CLUSTER_ID=$CLUSTER_ID"
# Environment="KAFKA_LOG4J_OPTS=-Dlog4j.configuration=file:/opt/kafka/config/kraft/log4j.properties"
# Environment="KAFKA_OPTS=-Djava.security.auth.login.config=/opt/kafka/config/kraft/jaas.conf"
# Environment="KAFKA_JVM_PERFORMANCE_OPTS=-XX:+UseG1GC -XX:MaxGCPauseMillis=20 -XX:InitiatingHeapOccupancyPercent=35 -XX:+ExplicitGCInvokesConcurrent"
# #ExecStartPre=sudo /opt/kafka/scripts/kafka-format.sh
# ExecStart=sudo /opt/kafka/bin/kafka-server-start.sh /opt/kafka/config/kraft/server.properties
# ExecStop=sudo /opt/kafka/bin/kafka-server-stop.sh /opt/kafka/config/kraft/server.properties
 
# [Install]
# WantedBy=multi-user.target
# EOF

sudo sed -i 's/#ClientAliveInterval 0/ClientAliveInterval 300/' /etc/ssh/sshd_config
sudo sed -i 's/#ClientAliveCountMax 3/ClientAliveCountMax 3/' /etc/ssh/sshd_config

echo "Installation completed successfully"