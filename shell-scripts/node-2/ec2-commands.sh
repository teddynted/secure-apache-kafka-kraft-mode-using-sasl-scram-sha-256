#!/bin/bash

KRAFT_ADVERTISED_LISTENERS=$(cat /opt/kafka/config/kraft/server.properties | grep -c "advertised.listeners=SASL_SSL://$4:9092")
echo 'KRAFT_ADVERTISED_LISTENERS '$KRAFT_ADVERTISED_LISTENERS''
if [[ $KRAFT_ADVERTISED_LISTENERS -eq 0 ]] 
then
sudo sed -i s/offsets.topic.replication.factor=1/offsets.topic.replication.factor=3/ /opt/kafka/config/kraft/server.properties
sudo sed -i s/transaction.state.log.replication.factor=1/transaction.state.log.replication.factor=2/ /opt/kafka/config/kraft/server.properties
sudo sed -i s/socket.receive.buffer.bytes=102400/socket.receive.buffer.bytes=1048576/ /opt/kafka/config/kraft/server.properties
sudo sed -i s/socket.send.buffer.bytes=102400/socket.send.buffer.bytes=1048576/ /opt/kafka/config/kraft/server.properties
sudo sed -i s/controller.quorum.voters=1@localhost:9093/controller.quorum.voters=1@$6:9093,2@$4:9093,3@$7:9093/ /opt/kafka/config/kraft/server.properties
sudo sed -i s/listeners=PLAINTEXT:\\/\\/:9092,CONTROLLER:\\/\\/:9093/listeners=SASL_SSL:\\/\\/:9092,CONTROLLER:\\/\\/:9093,EXTERNAL:\\/\\/:9094/ /opt/kafka/config/kraft/server.properties
sudo sed -i s/inter.broker.listener.name=PLAINTEXT/inter.broker.listener.name=SASL_SSL/ /opt/kafka/config/kraft/server.properties
sudo sed -i s/advertised.listeners=PLAINTEXT:\\/\\/localhost:9092,CONTROLLER:\\/\\/localhost:9093/advertised.listeners=SASL_SSL:\\/\\/$4:9092,CONTROLLER:\\/\\/$4:9093,EXTERNAL:\\/\\/$5:9094/ /opt/kafka/config/kraft/server.properties
sudo sed -i s/listener.security.protocol.map=CONTROLLER:PLAINTEXT,PLAINTEXT:PLAINTEXT,SSL:SSL,SASL_PLAINTEXT:SASL_PLAINTEXT,SASL_SSL:SASL_SSL/listener.security.protocol.map=CONTROLLER:SASL_SSL,EXTERNAL:SASL_SSL,SASL_SSL:SASL_SSL/ /opt/kafka/config/kraft/server.properties
sudo echo 'Create client properties'
sudo touch /opt/kafka/config/kraft/client.properties
sudo tee /opt/kafka/config/kraft/client.properties > /dev/null <<EOF
bootstrap.servers=$4:9092
security.protocol=SASL_SSL
ssl.truststore.location=/opt/kafka/config/kafka-ssl/truststore/kafka.truststore.jks
ssl.truststore.password=$1
sasl.mechanism=SCRAM-SHA-256
sasl.jaas.config=org.apache.kafka.common.security.scram.ScramLoginModule required username=$2 password=$1;
EOF
sudo touch /opt/kafka/config/kraft/ssl-consumer.properties
sudo tee /opt/kafka/config/kraft/ssl-consumer.properties > /dev/null <<EOF
bootstrap.servers=$4:9092
security.protocol=SASL_SSL
ssl.truststore.location=/opt/kafka/config/kafka-ssl/truststore/kafka.truststore.jks
ssl.truststore.password=$1
sasl.mechanism=SCRAM-SHA-256
sasl.jaas.config=org.apache.kafka.common.security.scram.ScramLoginModule required username=$2 password=$1;
group.id=demo-consumer-group
group.instance.id=demo-consumer-group-1
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
sudo touch /opt/kafka/config/kraft/ssl-producer.properties
sudo tee /opt/kafka/config/kraft/ssl-producer.properties > /dev/null <<EOF
bootstrap.servers=$4:9092
compression.type=none
security.protocol=SASL_SSL
ssl.truststore.location=/opt/kafka/config/kafka-ssl/truststore/kafka.truststore.jks
ssl.truststore.password=$1
sasl.mechanism=SCRAM-SHA-256
sasl.jaas.config=org.apache.kafka.common.security.scram.ScramLoginModule required username=$2 password=$1;
EOF
sudo systemctl daemon-reload
sudo systemctl enable kafka
sudo systemctl start kafka
sudo systemctl status kafka
sudo sleep 10
sudo /opt/kafka/bin/kafka-topics.sh --create --bootstrap-server $4:9092 --replication-factor 3 --partitions 3 --topic testtopic --if-not-exists --command-config /opt/kafka/config/kraft/client.properties
sudo sleep 10
sudo /opt/kafka/bin/kafka-topics.sh --bootstrap-server $4:9092 --list --command-config /opt/kafka/config/kraft/client.properties
sudo sleep 10
sudo /opt/kafka/bin/kafka-topics.sh --describe --bootstrap-server $4:9092 --command-config /opt/kafka/config/kraft/client.properties --topic first-topic
sudo sleep 10
sudo /opt/kafka/bin/kafka-metadata-quorum.sh --bootstrap-server $4:9092 --command-config /opt/kafka/config/kraft/client.properties describe --status
sudo sleep 5
sudo cat /opt/kafka/config/kraft/server.properties
fi

