#!/bin/bash -u

echo $1 $2 $3 $4 $5 $6 $7 $8 $9 $10
sudo yum update -y
sudo yum install -y java-11-amazon-corretto
sudo yum install -y git
sudo yum -y install telnet
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
sudo mkdir /opt/kafka/config/kafka-ssl
git clone https://github.com/confluentinc/confluent-platform-security-tools.git  /opt/kafka/config/kafka-ssl
sudo chmod +x /opt/kafka/config/kafka-ssl/kafka-generate-ssl-automatic.sh
cd /opt/kafka/config/kafka-ssl/
echo COUNTRY=$4 >> /etc/environment
echo STATE=$3 >> /etc/environment
echo ORGANIZATION_UNIT=PX >> /etc/environment
echo CITY=Johannesburg >> /etc/environment
echo PASSWORD=$2 >> /etc/environment
echo USERNAME=$1 >> /etc/environment
sudo ./kafka-generate-ssl-automatic.sh
ls -l
cd ../../../../
ls -l
#CLUSTER_ID=$(/opt/kafka/bin/kafka-storage.sh random-uuid)
echo "Region: $10"
CLUSTER_ID=$(aws ssm get-parameter --name /kafka/cluster-id --query "Parameter.Value" --output text --region "eu-west-1")
echo "CLUSTER_ID: $CLUSTER_ID"
sudo mkdir /opt/kafka/scripts
sudo mkdir /opt/kafka/config/kraft/kraft-combined-logs
sudo touch /opt/kafka/scripts/kafka-format.sh
sudo cat <<EOF > /opt/kafka/scripts/kafka-format.sh
#!/bin/bash
set -euo pipefail
echo "Formatting Kafka KRaft storage with CLUSTER_ID=$CLUSTER_ID"
sudo /opt/kafka/bin/kafka-storage.sh format --config /opt/kafka/config/kraft/server.properties --cluster-id $CLUSTER_ID --add-scram SCRAM-SHA-256=[name=$1,password=$2] --ignore-formatted
EOF
      
sudo chmod +x /opt/kafka/scripts/kafka-format.sh

sudo touch /opt/kafka/config/kraft/jaas.conf
sudo cat <<EOF > /opt/kafka/config/kraft/jaas.conf
KafkaServer {
    org.apache.kafka.common.security.scram.ScramLoginModule required username=$1 password=$2 user_admin=$2 user_broker1=$2;
};
KafkaController {
  org.apache.kafka.common.security.scram.ScramLoginModule required
  username="controller"
  password=$2;
};
EOF

sudo touch /opt/kafka/config/kraft/log4j.properties
sudo cat <<EOF > /opt/kafka/config/kraft/log4j.properties
log4j.rootLogger=INFO, stdout, kafkaAppender
log4j.appender.stdout=org.apache.log4j.ConsoleAppender
log4j.appender.stdout.layout=org.apache.log4j.PatternLayout
log4j.appender.stdout.layout.ConversionPattern=[%d] %p %m (%c)%n
log4j.appender.kafkaAppender=org.apache.log4j.RollingFileAppender
log4j.appender.kafkaAppender.File=/var/log/kafka/server.log
log4j.appender.kafkaAppender.MaxFileSize=100MB
log4j.appender.kafkaAppender.MaxBackupIndex=10
log4j.appender.kafkaAppender.layout=org.apache.log4j.PatternLayout
log4j.appender.kafkaAppender.layout.ConversionPattern=[%d] %p %m (%c)%n
log4j.logger.org.apache.kafka.metadata=DEBUG
log4j.logger.org.apache.kafka.raft=DEBUG
log4j.logger.org.apache.kafka.controller=DEBUG
log4j.logger.org.apache.kafka.quorum=DEBUG
log4j.logger.org.apache.kafka.common.network.SslTransportLayer=DEBUG
log4j.logger.org.apache.kafka.common.security.ssl.SslFactory=DEBUG
log4j.logger.kafka=INFO
log4j.logger.org.apache.kafka.clients=DEBUG
log4j.logger.org.apache.kafka.common.network.Selector=DEBUG
log4j.logger.kafka.log.Log=DEBUG
log4j.logger.kafka.raft.RaftClient=TRACE
log4j.logger.org.apache.kafka.clients.consumer.internals=DEBUG
log4j.logger.org.apache.kafka.clients.consumer.internals.ConsumerCoordinator=DEBUG
EOF

sudo mkdir -p /var/lib/kafka/logs
sudo chmod -R 700 /var/lib/kafka
sudo chown -R ec2-user:ec2-user /var/lib/kafka
sudo sed -i s/node.id=1/node.id=$7/ /opt/kafka/config/kraft/server.properties
sudo sed -i s/num.partitions=1/num.partitions=8/ /opt/kafka/config/kraft/server.properties
sudo sed -i s/log.dirs=\\/tmp\\/kraft-combined-logs/log.dirs=\\/opt\\/kafka\\/config\\/kraft\\/kraft-combined-logs/ /opt/kafka/config/kraft/server.properties

sudo sh -c 'cat << EOF >> /opt/kafka/config/kraft/server.properties
sasl.enabled.mechanisms=SCRAM-SHA-256
sasl.mechanism.controller.protocol=SCRAM-SHA-256
# security.inter.broker.protocol=SASL_SSL 
sasl.mechanism.inter.broker.protocol=SCRAM-SHA-256
# ssl.client.auth=required
ssl.protocol=TLS
ssl.cipher.suites=TLS_ECDHE_ECDSA_WITH_AES_256_GCM_SHA384,TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384
ssl.enabled.protocols=TLSv1.2,TLSv1.1,TLSv1
ssl.truststore.location=/opt/kafka/config/kafka-ssl/truststore/kafka.truststore.jks
ssl.truststore.type=PKCS12
ssl.truststore.password='$2'
ssl.keystore.location=/opt/kafka/config/kafka-ssl/keystore/kafka.keystore.jks
ssl.keystore.type=PKCS12
ssl.keystore.password='$2'
ssl.key.password='$2'
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
#authorizer.class.name=kafka.security.authorizer.AclAuthorizer
allow.everyone.if.no.acl.found=true
super.users=User:admin;User:controller;User:broker;User:producer;User:consumer
delete.topic.enable=true
default.replication.factor=3
min.insync.replicas=2
auto.create.topics.enable=true
unclean.leader.election.enable=false
controller.quorum.append.linger.ms=10
controller.quorum.election.timeout.ms=2000
num.replica.alter.log.dirs.threads=4
controller.quorum.election.timeout.ms=1000
connections.max.idle.ms=600000
socket.connection.setup.timeout.ms=30000
socket.connection.setup.timeout.max.ms=30000
log.retention.hours=1
log.segment.bytes=10485760
EOF'
      
echo 'export KAFKA_HEAP_OPTS="-Xms1G -Xmx1G"' >> /etc/environment
#echo 'export KAFKA_HEAP_OPTS="-Xmx384m -Xms384m"' >> /etc/environment
echo 'export KAFKA_OPTS="-Djava.security.auth.login.config=/opt/kafka/config/kraft/jaas.conf"' >> /etc/environment
echo 'export KAFKA_JVM_PERFORMANCE_OPTS="-XX:+UseG1GC -XX:MaxGCPauseMillis=20 -XX:InitiatingHeapOccupancyPercent=35 -XX:+ExplicitGCInvokesConcurrent"' >> /etc/environment
# Debugging errors
echo 'KAFKA_LOG4J_OPTS="-Dlog4j.configuration=file:/opt/kafka/config/kraft/log4j.properties"' >> /etc/environment
# Create Kafka service
sudo cat <<EOF > /etc/systemd/system/kafka.service
[Unit]
Description=Kafka Service
After=network-online.target
Requires=network-online.target
 
[Service]
Type=simple
User=ec2-user
Restart=on-failure
SyslogIdentifier=kafka
Environment="KAFKA_HEAP_OPTS='-Xms1G -Xmx1G'"
#Environment="KAFKA_HEAP_OPTS='-Xmx384m -Xms384m'"
Environment="CLUSTER_ID=$CLUSTER_ID"
Environment="KAFKA_LOG4J_OPTS=-Dlog4j.configuration=file:/opt/kafka/config/kraft/log4j.properties"
Environment="KAFKA_OPTS=-Djava.security.auth.login.config=/opt/kafka/config/kraft/jaas.conf"
Environment="KAFKA_JVM_PERFORMANCE_OPTS=-XX:+UseG1GC -XX:MaxGCPauseMillis=20 -XX:InitiatingHeapOccupancyPercent=35 -XX:+ExplicitGCInvokesConcurrent"
ExecStartPre=sudo /opt/kafka/scripts/kafka-format.sh
ExecStart=sudo /opt/kafka/bin/kafka-server-start.sh /opt/kafka/config/kraft/server.properties
ExecStop=sudo /opt/kafka/bin/kafka-server-stop.sh /opt/kafka/config/kraft/server.properties
 
[Install]
WantedBy=multi-user.target
EOF

sudo sed -i 's/#ClientAliveInterval 0/ClientAliveInterval 300/' /etc/ssh/sshd_config
sudo sed -i 's/#ClientAliveCountMax 3/ClientAliveCountMax 3/' /etc/ssh/sshd_config

echo "Installation completed successfully"