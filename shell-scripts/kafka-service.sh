#!/bin/bash

NODE_ID=$3
CERT="/opt/kafka/config/kafka-ssl/kafka-certs/node-$NODE_ID"
echo "CERT directory $CERT"
PRIVATE_DNS_NAME_NODE=$1
REGION=$(aws ec2 describe-availability-zones --output text --query 'AvailabilityZones[0].[RegionName]')
KRAFT_ADVERTISED_LISTENERS=$(cat /opt/kafka/config/kraft/server.properties | grep -c "advertised.listeners=CLIENT://$PRIVATE_DNS_NAME_NODE:9092")
echo 'KRAFT_ADVERTISED_LISTENERS '$KRAFT_ADVERTISED_LISTENERS''
if [[ $KRAFT_ADVERTISED_LISTENERS -eq 0 ]] 
then
PUBLIC_IP_ADDRESS_NODE=$2
VOTERS=$4
echo "NODE_ID: $NODE_ID, VOTERS: $VOTERS"
SECRET_JSON=$(aws secretsmanager get-secret-value --secret-id "KafkaBrokerSaslScram256" --region $REGION --query SecretString --output text)
PASSWORD=$(echo "$SECRET_JSON" | jq -r .password)
USERNAME=$(echo "$SECRET_JSON" | jq -r .username)
sudo sed -i s/offsets.topic.replication.factor=1/offsets.topic.replication.factor=3/ /opt/kafka/config/kraft/server.properties
sudo sed -i s/transaction.state.log.replication.factor=1/transaction.state.log.replication.factor=2/ /opt/kafka/config/kraft/server.properties
sudo sed -i s/socket.receive.buffer.bytes=102400/socket.receive.buffer.bytes=1048576/ /opt/kafka/config/kraft/server.properties
sudo sed -i s/socket.send.buffer.bytes=102400/socket.send.buffer.bytes=1048576/ /opt/kafka/config/kraft/server.properties
sudo sed -i s/controller.quorum.voters=1@localhost:9093/$VOTERS/ /opt/kafka/config/kraft/server.properties
sudo sed -i s/listeners=PLAINTEXT:\\/\\/:9092,CONTROLLER:\\/\\/:9093/listeners=CLIENT:\\/\\/:9092,INTERNAL:\\/\\/:9093,CONTROLLER:\\/\\/:9094/ /opt/kafka/config/kraft/server.properties
sudo sed -i s/advertised.listeners=PLAINTEXT:\\/\\/localhost:9092,CONTROLLER:\\/\\/localhost:9093/advertised.listeners=CLIENT:\\/\\/$PRIVATE_DNS_NAME_NODE:9092,INTERNAL:\\/\\/$PRIVATE_DNS_NAME_NODE:9093/ /opt/kafka/config/kraft/server.properties
sudo sed -i s/listener.security.protocol.map=CONTROLLER:PLAINTEXT,PLAINTEXT:PLAINTEXT,SSL:SSL,SASL_PLAINTEXT:SASL_PLAINTEXT,SASL_SSL:SASL_SSL/listener.security.protocol.map=CONTROLLER:SASL_SSL,INTERNAL:SASL_SSL,CLIENT:SASL_SSL/ /opt/kafka/config/kraft/server.properties
sudo echo 'Create client properties'
sudo touch /opt/kafka/config/kraft/client.properties
sudo tee /opt/kafka/config/kraft/client.properties > /dev/null <<EOF
bootstrap.servers=$PRIVATE_DNS_NAME_NODE:9092
security.protocol=SASL_SSL
#ssl.truststore.location=/opt/kafka/config/kafka-ssl/truststore/kafka.truststore.jks
ssl.truststore.location=$CERT/truststore.jks
ssl.truststore.password=$PASSWORD
ssl.truststore.type=PKCS12
sasl.mechanism=SCRAM-SHA-256
sasl.jaas.config=org.apache.kafka.common.security.scram.ScramLoginModule required username=$USERNAME password=$PASSWORD;
EOF
sudo touch /opt/kafka/config/kraft/ssl-consumer.properties
sudo tee /opt/kafka/config/kraft/ssl-consumer.properties > /dev/null <<EOF
bootstrap.servers=$PRIVATE_DNS_NAME_NODE:9092
security.protocol=SASL_SSL
ssl.truststore.location=$CERT/truststore.jks
#ssl.truststore.location=/opt/kafka/config/kafka-ssl/truststore/kafka.truststore.jks
ssl.truststore.password=$PASSWORD
ssl.truststore.type=PKCS12
sasl.mechanism=SCRAM-SHA-256
sasl.jaas.config=org.apache.kafka.common.security.scram.ScramLoginModule required username=$USERNAME password=$PASSWORD;
key.deserializer=org.apache.kafka.common.serialization.StringDeserializer
value.deserializer=org.apache.kafka.common.serialization.StringDeserializer
auto.offset.reset=earliest
enable.auto.commit=true
auto.commit.interval.ms=5000
session.timeout.ms=45000
heartbeat.interval.ms=15000
max.poll.interval.ms=300000
partition.assignment.strategy=org.apache.kafka.clients.consumer.CooperativeStickyAssignor
EOF

CLUSTER_ID=$(aws ssm get-parameter --name /kafka/cluster-id --query "Parameter.Value" --output text --region $REGION)
echo "CLUSTER_ID: $CLUSTER_ID"
sudo mkdir /opt/kafka/scripts
sudo mkdir /opt/kafka/config/kraft/kraft-combined-logs
sudo touch /opt/kafka/scripts/kafka-format.sh
sudo tee /opt/kafka/scripts/kafka-format.sh > /dev/null <<EOF
#!/bin/bash
set -euo pipefail
if [ ! -f /opt/kafka/config/kraft/kraft-combined-logs/meta.properties ]; then
echo "Formatting Kafka KRaft storage with CLUSTER_ID=$CLUSTER_ID"
sudo /opt/kafka/bin/kafka-storage.sh format --config /opt/kafka/config/kraft/server.properties --cluster-id $CLUSTER_ID --add-scram SCRAM-SHA-256=[name=$USERNAME,password=$PASSWORD] --ignore-formatted
fi
EOF
      
sudo chmod +x /opt/kafka/scripts/kafka-format.sh

sudo touch /opt/kafka/config/kraft/jaas.conf
sudo tee /opt/kafka/config/kraft/jaas.conf > /dev/null <<EOF
KafkaServer {
    org.apache.kafka.common.security.scram.ScramLoginModule required username=$USERNAME password=$PASSWORD;
};
EOF

sudo touch /opt/kafka/config/kraft/log4j.properties 
sudo tee /opt/kafka/config/kraft/log4j.properties > /dev/null <<EOF
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
log4j.logger.org.apache.kafka.clients=DEBUG
log4j.logger.org.apache.kafka.common.network.Selector=DEBUG
log4j.logger.kafka.log.Log=DEBUG
log4j.logger.kafka.raft.RaftClient=TRACE
log4j.logger.org.apache.kafka.clients.consumer.internals=DEBUG
log4j.logger.org.apache.kafka.clients.consumer.internals.ConsumerCoordinator=DEBUG
log4j.logger.kafka=DEBUG
log4j.logger.kafka.authorizer.logger=DEBUG
log4j.logger.kafka.server.KafkaApis=DEBUG
log4j.logger.kafka.network=DEBUG
log4j.logger.org.apache.kafka.common.network.SaslChannelBuilder=DEBUG
log4j.logger.org.apache.kafka.common.security.scram=DEBUG
log4j.logger.org.apache.kafka=DEBUG
log4j.logger.org.apache.kafka.common=DEBUG
log4j.logger.org.apache.kafka.raft=DEBUG
log4j.logger.org.apache.kafka.network=DEBUG
log4j.logger.kafka.server.Authentication=DEBUG
log4j.logger.kafka.raft=TRACE
EOF

echo 'KAFKA_HEAP_OPTS="-Xms1G -Xmx1G"' | sudo tee -a /etc/environment
echo 'KAFKA_OPTS="-Djava.security.auth.login.config=/opt/kafka/config/kraft/jaas.conf"' | sudo tee -a /etc/environment
echo 'KAFKA_JVM_PERFORMANCE_OPTS="-XX:+UseG1GC -XX:MaxGCPauseMillis=20 -XX:InitiatingHeapOccupancyPercent=35 -XX:+ExplicitGCInvokesConcurrent"' | sudo tee -a /etc/environment
echo 'KAFKA_LOG4J_OPTS="-Dlog4j.configuration=file:/opt/kafka/config/kraft/log4j.properties"' | sudo tee -a /etc/environment
echo 'KAFKA_HEAP_OPTS="-Xms1G -Xmx1G"' | sudo tee -a /etc/environment
source /etc/environment

export JAVA_HOME=/usr/lib/jvm/java-11-amazon-corretto
# Create Kafka service
sudo tee /etc/systemd/system/kafka.service > /dev/null <<EOF
[Unit]
Description=Apache Kafka Server (KRaft Mode)
Documentation=https://kafka.apache.org/documentation/#kraft
After=network.target

[Service]
Type=simple
User=ec2-user
Group=ec2-user
Environment="JAVA_HOME=/usr/lib/jvm/java-11-amazon-corretto"  # Kafka 3.4+ needs Java 11+
Environment="KAFKA_HEAP_OPTS=-Xms2G -Xmx2G"  # KRaft may need more memory
Environment="KAFKA_OPTS=-javaagent:/opt/kafka/libs/jmx_prometheus_javaagent-0.17.2.jar=7071:/opt/kafka/config/jmx_exporter.yml"  # Optional JMX exporter
Environment="KAFKA_LOG4J_OPTS=-Dlog4j.configuration=file:/opt/kafka/config/kraft/log4j.properties"
Environment="KAFKA_OPTS=-Djava.security.auth.login.config=/opt/kafka/config/kraft/jaas.conf"
Environment="KAFKA_JVM_PERFORMANCE_OPTS=-XX:+UseG1GC -XX:MaxGCPauseMillis=20 -XX:InitiatingHeapOccupancyPercent=35 -XX:+ExplicitGCInvokesConcurrent"
# For KRaft controller+broker combined mode
ExecStart=/opt/kafka/bin/kafka-server-start.sh /opt/kafka/config/kraft/server.properties

# For separate controller and broker nodes, use appropriate properties file
# ExecStart=/opt/kafka/bin/kafka-server-start.sh /opt/kafka/config/kraft/controller.properties
# or
# ExecStart=/opt/kafka/bin/kafka-server-start.sh /opt/kafka/config/kraft/broker.properties

ExecStop=/opt/kafka/bin/kafka-server-stop.sh
Restart=on-failure
RestartSec=30  # Longer restart sec for KRaft to avoid rapid restart cycles
LimitNOFILE=100000
LimitNPROC=100000
TimeoutStopSec=60  # KRaft needs more time to shutdown gracefully
SuccessExitStatus=143

# Logging configuration
StandardOutput=file:/var/log/kafka/kafka.out
StandardError=file:/var/log/kafka/kafka.err
SyslogIdentifier=kafka-kraft

[Install]
WantedBy=multi-user.target
EOF

sudo chmod 644 /etc/systemd/system/kafka.service
sudo systemctl daemon-reload
sudo systemctl enable kafka
# Open ports (e.g., Kafka)
sudo firewall-cmd --add-port=9092/tcp --permanent
sudo firewall-cmd --add-port=9093/tcp --permanent
sudo firewall-cmd --add-port=9094/tcp --permanent

# Reload firewall rules
sudo firewall-cmd --reload
sudo systemctl enable chronyd
sudo systemctl start chronyd
fi
