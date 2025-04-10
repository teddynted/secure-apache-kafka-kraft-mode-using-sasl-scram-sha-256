#!/bin/bash

PUBLIC_IP_ADDRESS=$(ec2-metadata --public-ipv4 | cut -d " " -f 2);
PRIVATE_IP_ADDRESS=$(ec2-metadata --local-ipv4 | cut -d " " -f 2);
echo "EC2 PUBLIC_IP_ADDRESS: '$PUBLIC_IP_ADDRESS'"
echo "EC2 PRIVATE_IP_ADDRESS: '$PRIVATE_IP_ADDRESS'"

KRAFT_ADVERTISED_LISTENERS=$(cat /opt/kafka/config/kraft/server.properties | grep -c "advertised.listeners=SASL_SSL://$PUBLIC_IP_ADDRESS:9092")
echo 'KRAFT_ADVERTISED_LISTENERS '$KRAFT_ADVERTISED_LISTENERS''
if [[ $KRAFT_ADVERTISED_LISTENERS -eq 0 ]] 
then
sudo sed -i s/offsets.topic.replication.factor=1/offsets.topic.replication.factor=2/ /opt/kafka/config/kraft/server.properties
sudo sed -i s/transaction.state.log.replication.factor=1/transaction.state.log.replication.factor=2/ /opt/kafka/config/kraft/server.properties
sudo sed -i s/socket.receive.buffer.bytes=102400/socket.receive.buffer.bytes=1048576/ /opt/kafka/config/kraft/server.properties
sudo sed -i s/socket.send.buffer.bytes=102400/socket.send.buffer.bytes=1048576/ /opt/kafka/config/kraft/server.properties
sudo sed -i s/controller.quorum.voters=1@localhost:9093/controller.quorum.voters=1@$PRIVATE_IP_ADDRESS:9094/ /opt/kafka/config/kraft/server.properties
sudo sed -i s/listeners=PLAINTEXT:\\/\\/:9092,CONTROLLER:\\/\\/:9093/listeners=SASL_SSL:\\/\\/:9092,INTERNAL://:9093,CONTROLLER:\\/\\/:9094/ /opt/kafka/config/kraft/server.properties
sudo sed -i s/inter.broker.listener.name=PLAINTEXT/inter.broker.listener.name=INTERNAL/ /opt/kafka/config/kraft/server.properties
sudo sed -i s/advertised.listeners=PLAINTEXT:\\/\\/localhost:9092,CONTROLLER:\\/\\/localhost:9093/advertised.listeners=SASL_SSL:\\/\\/$PUBLIC_IP_ADDRESS:9092/ /opt/kafka/config/kraft/server.properties
sudo sed -i s/listener.security.protocol.map=CONTROLLER:PLAINTEXT,PLAINTEXT:PLAINTEXT,SSL:SSL,SASL_PLAINTEXT:SASL_PLAINTEXT,SASL_SSL:SASL_SSL/listener.security.protocol.map=INTERNAL:SASL_SSL,CONTROLLER:SASL_SSL,SASL_SSL:SASL_SSL/ /opt/kafka/config/kraft/server.properties
# sudo /opt/kafka/bin/kafka-acls.sh --bootstrap-server $PUBLIC_IP_ADDRESS:9092 --add --allow-principal "User:broker1" --operation ClusterAction --cluster
# sudo /opt/kafka/bin/kafka-acls.sh --bootstrap-server $PUBLIC_IP_ADDRESS:9092 --list --cluster
sudo systemctl daemon-reload
sudo systemctl enable kafka
sudo systemctl start kafka
sudo systemctl status kafka
echo 'SASL_SCRAM_PASSWORD '$SASL_SCRAM_PASSWORD''
sudo /opt/kafka/bin/kafka-configs.sh --bootstrap-server $PRIVATE_IP_ADDRESS:9092 --alter --add-config 'SCRAM-SHA-256=[password='$SASL_SCRAM_PASSWORD']' --entity-type users --entity-name admin
sudo /opt/kafka/bin/kafka-configs.sh --bootstrap-server $PRIVATE_IP_ADDRESS:9092 --alter --add-config 'SCRAM-SHA-256=[password='$SASL_SCRAM_PASSWORD']' --entity-type users --entity-name broker
sudo /opt/kafka/bin/kafka-configs.sh --bootstrap-server $PRIVATE_IP_ADDRESS:9092 --alter --add-config 'SCRAM-SHA-256=[password='$SASL_SCRAM_PASSWORD']' --entity-type users --entity-name controller
sudo systemctl restart kafka
sudo systemctl status kafka -l
fi

cat /var/log/cloud-init-output.log
cat /opt/kafka/logs/server.log
cat /opt/kafka/config/kraft/server.properties
#sudo systemctl list-unit-files --type=service

# Create a topic if doesn't exists
#sudo /opt/kafka/bin/kafka-topics.sh --create --bootstrap-server $PUBLIC_IP_ADDRESS:9092 --replication-factor 1 --partitions 3 --topic testtopic --if-not-exists --command-config /opt/kafka/config/kraft/admin.config

# List all the existing topics
#sudo /opt/kafka/bin/kafka-topics.sh --bootstrap-server $PUBLIC_IP_ADDRESS:9092 --list --command-config /opt/kafka/config/kraft/admin.config

# sudo ss -tulnp | grep java
# tail -f /opt/kafka/logs/server.log
# curl ifconfig.me
# journalctl -u kafka -f

#sudo /opt/kafka/bin/kafka-configs.sh --bootstrap-server localhost:9092 --entity-type users --describe --entity-name admin
#ExecStartPre=sudo /opt/kafka/bin/kafka-storage.sh format --config /opt/kafka/config/kraft/server.properties --cluster-id $CLUSTER_ID --add-scram SCRAM-SHA-256=[name=${username},password=${password}]
#sudo /opt/kafka/bin/kafka-metadata-quorum.sh --bootstrap-server $PUBLIC_IP_ADDRESS:9092 --command-config config/client.properties describe --status
#sudo /opt/kafka/bin/kafka-topics.sh --bootstrap-server 34.250.196.150:9092 --list --command-config /opt/kafka/config/kraft/admin.config

# Consuming Message

#sudo /opt/kafka/bin/kafka-console-consumer.sh --bootstrap-server 34.250.196.150:9092 --topic testtopic --from-beginning --consumer.config /opt/kafka/config/kraft/admin.config

# Produce Messsage

#sudo /opt/kafka/bin/kafka-console-producer.sh --bootstrap-server 54.155.178.235:9092 --topic testtopic --producer.config /opt/kafka/config/kraft/admin.config
#sudo /opt/kafka/bin/kafka-topics.sh --bootstrap-server 34.250.196.150:9092 --list

#sudo /opt/kafka/bin/kafka-metadata-quorum.sh --bootstrap-controller 34.250.196.150:9092 describe --status
#sudo /opt/kafka/bin/kafka-topics.sh --bootstrap-server 172.31.30.39:9092 --list --command-config /opt/kafka/config/kraft/admin.config
#sudo /opt/kafka/bin/kafka-metadata-quorum.sh --bootstrap-server 54.78.163.240:9092 describe --status --command-config /opt/kafka/config/kraft/admin.config
#journalctl -xeu kafka.service
#sudo /opt/kafka/bin/kafka-acls.sh --bootstrap-server 54.78.163.240:9092 --add --allow-principal "User:broker1" --operation ClusterAction --cluster /opt/kafka/config/kraft/admin.config
#sudo /opt/kafka/bin/kafka-acls.sh --bootstrap-server 54.78.163.240:9092 --list --cluster
#cat /var/bin/kafka/logs/meta.properties


