#!/bin/bash

NODE_ID=$8
CERT="/opt/kafka/config/kafka-ssl/kafka-certs/node-$NODE_ID"
PRIVATE_DNS_NAME_NODE=$1
REGION=$(aws ec2 describe-availability-zones --output text --query 'AvailabilityZones[0].[RegionName]')
echo "CERT directory $CERT"
KRAFT_ADVERTISED_LISTENERS=$(cat /opt/kafka/config/kraft/server.properties | grep -c "advertised.listeners=SASL_SSL://$PRIVATE_DNS_NAME_NODE:9092")
echo 'KRAFT_ADVERTISED_LISTENERS '$KRAFT_ADVERTISED_LISTENERS''
if [[ $KRAFT_ADVERTISED_LISTENERS -eq 0 ]] 
then
PUBLIC_IP_ADDRESS_NODE=$2
PRIVATE_DNS_NAME_NODE_1=$3
PRIVATE_DNS_NAME_NODE_2=$4
SECRET_JSON=$(aws secretsmanager get-secret-value --secret-id "KafkaBrokerSaslScram256" --region $REGION --query SecretString --output text)
PASSWORD=$(echo "$SECRET_JSON" | jq -r .password)
USERNAME=$(echo "$SECRET_JSON" | jq -r .username)
sudo sed -i s/offsets.topic.replication.factor=1/offsets.topic.replication.factor=3/ /opt/kafka/config/kraft/server.properties
sudo sed -i s/transaction.state.log.replication.factor=1/transaction.state.log.replication.factor=2/ /opt/kafka/config/kraft/server.properties
sudo sed -i s/socket.receive.buffer.bytes=102400/socket.receive.buffer.bytes=1048576/ /opt/kafka/config/kraft/server.properties
sudo sed -i s/socket.send.buffer.bytes=102400/socket.send.buffer.bytes=1048576/ /opt/kafka/config/kraft/server.properties
sudo sed -i s/controller.quorum.voters=1@localhost:9093/controller.quorum.voters=1@$PRIVATE_DNS_NAME_NODE_1:9093,2@$PRIVATE_DNS_NAME_NODE_2:9093,3@$PRIVATE_DNS_NAME_NODE:9093/ /opt/kafka/config/kraft/server.properties
sudo sed -i s/listeners=PLAINTEXT:\\/\\/:9092,CONTROLLER:\\/\\/:9093/listeners=SASL_SSL:\\/\\/:9092,CONTROLLER:\\/\\/:9093,EXTERNAL:\\/\\/:9094/ /opt/kafka/config/kraft/server.properties
#sudo sed -i s/inter.broker.listener.name=PLAINTEXT/inter.broker.listener.name=SASL_SSL/ /opt/kafka/config/kraft/server.properties
sudo sed -i s/advertised.listeners=PLAINTEXT:\\/\\/localhost:9092,CONTROLLER:\\/\\/localhost:9093/advertised.listeners=SASL_SSL:\\/\\/$PRIVATE_DNS_NAME_NODE:9092,CONTROLLER:\\/\\/$PRIVATE_DNS_NAME_NODE:9093,EXTERNAL:\\/\\/$PUBLIC_IP_ADDRESS_NODE:9094/ /opt/kafka/config/kraft/server.properties
sudo sed -i s/listener.security.protocol.map=CONTROLLER:PLAINTEXT,PLAINTEXT:PLAINTEXT,SSL:SSL,SASL_PLAINTEXT:SASL_PLAINTEXT,SASL_SSL:SASL_SSL/listener.security.protocol.map=CONTROLLER:SASL_SSL,EXTERNAL:SASL_SSL,SASL_SSL:SASL_SSL/ /opt/kafka/config/kraft/server.properties
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
#ssl.truststore.location=/opt/kafka/config/kafka-ssl/truststore/kafka.truststore.jks
ssl.truststore.location=$CERT/truststore.jks
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
sudo systemctl enable chronyd
sudo systemctl start chronyd
fi
