#!/bin/bash

PUBLIC_IP_ADDRESS=$(ec2-metadata --public-ipv4 | cut -d " " -f 2);
PRIVATE_IP_ADDRESS=$(ec2-metadata --local-ipv4 | cut -d " " -f 2);
echo "EC2 PUBLIC_IP_ADDRESS: '$PUBLIC_IP_ADDRESS'"
echo "EC2 PRIVATE_IP_ADDRESS: '$PRIVATE_IP_ADDRESS'"

KRAFT_ADVERTISED_LISTENERS=$(cat /opt/kafka/config/kraft/server.properties | grep -c "advertised.listeners=SASL_SSL://$PRIVATE_IP_ADDRESS:9092")
echo 'KRAFT_ADVERTISED_LISTENERS '$KRAFT_ADVERTISED_LISTENERS''
if [[ $KRAFT_ADVERTISED_LISTENERS -eq 0 ]] 
then
sudo sed -i s/offsets.topic.replication.factor=1/offsets.topic.replication.factor=2/ /opt/kafka/config/kraft/server.properties
sudo sed -i s/transaction.state.log.replication.factor=1/transaction.state.log.replication.factor=2/ /opt/kafka/config/kraft/server.properties
sudo sed -i s/socket.receive.buffer.bytes=102400/socket.receive.buffer.bytes=1048576/ /opt/kafka/config/kraft/server.properties
sudo sed -i s/socket.send.buffer.bytes=102400/socket.send.buffer.bytes=1048576/ /opt/kafka/config/kraft/server.properties
sudo sed -i s/controller.quorum.voters=1@localhost:9093/controller.quorum.voters=1@$PRIVATE_IP_ADDRESS:9093/ /opt/kafka/config/kraft/server.properties
sudo sed -i s/listeners=PLAINTEXT:\\/\\/:9092,CONTROLLER:\\/\\/:9093/listeners=SASL_SSL:\\/\\/$PRIVATE_IP_ADDRESS:9092,CONTROLLER:\\/\\/$PRIVATE_IP_ADDRESS:9093/ /opt/kafka/config/kraft/server.properties
sudo sed -i s/inter.broker.listener.name=PLAINTEXT/inter.broker.listener.name=SASL_SSL/ /opt/kafka/config/kraft/server.properties
sudo sed -i s/advertised.listeners=PLAINTEXT:\\/\\/localhost:9092,CONTROLLER:\\/\\/localhost:9093/advertised.listeners=SASL_SSL:\\/\\/$PUBLIC_IP_ADDRESS:9092/ /opt/kafka/config/kraft/server.properties
sudo sed -i s/listener.security.protocol.map=CONTROLLER:PLAINTEXT,PLAINTEXT:PLAINTEXT,SSL:SSL,SASL_PLAINTEXT:SASL_PLAINTEXT,SASL_SSL:SASL_SSL/listener.security.protocol.map=CONTROLLER:SASL_SSL,SSL:SSL,SASL_PLAINTEXT:SASL_PLAINTEXT,SASL_SSL:SASL_SSL/ /opt/kafka/config/kraft/server.properties
fi

sudo systemctl daemon-reload
sudo systemctl restart kafka
sudo systemctl status kafka
sudo systemctl list-unit-files --type=service

# Create a topic if doesn't exists
sudo /opt/kafka/bin/kafka-topics.sh --create --bootstrap-server $PUBLIC_IP_ADDRESS:9092 --replication-factor 1 --partitions 3 --topic testtopic --if-not-exists --command-config /opt/kafka/config/kraft/admin.config

# List all the existing topics
sudo /opt/kafka/bin/kafka-topics.sh --bootstrap-server $PUBLIC_IP_ADDRESS:9092 --list --command-config /opt/kafka/config/kraft/admin.config

# Consuming Message

#sudo /opt/kafka/bin/kafka-console-consumer.sh --bootstrap-server PUBLIC_IP_ADDRESS:9092 --topic testtopic --from-beginning --consumer.config /opt/kafka/config/kraft/admin.config

#sudo KAFKA_OPTS="-Djavax.net.debug=ssl" sudo /opt/kafka/bin/kafka-console-consumer.sh --broker-list 18.201.34.55:9092 --topic testtopic --producer.config /opt/kafka/config/kraft/admin.config

# Produce Messsage

#sudo /opt/kafka/bin/kafka-console-producer.sh --bootstrap-server 18.201.34.55:9092 --topic testtopic --producer.config /opt/kafka/config/kraft/admin.config


