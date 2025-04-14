#!/bin/bash

PUBLIC_IP_ADDRESS=$(ec2-metadata --public-ipv4 | cut -d " " -f 2);
PRIVATE_IP_ADDRESS=$(ec2-metadata --local-ipv4 | cut -d " " -f 2);
echo "EC2 PUBLIC_IP_ADDRESS: '$PUBLIC_IP_ADDRESS'"
echo "EC2 PRIVATE_IP_ADDRESS: '$PRIVATE_IP_ADDRESS'"

KRAFT_ADVERTISED_LISTENERS=$(cat /opt/kafka/config/kraft/server.properties | grep -c "advertised.listeners=CLIENT://$PUBLIC_IP_ADDRESS:9092")
echo 'KRAFT_ADVERTISED_LISTENERS '$KRAFT_ADVERTISED_LISTENERS''
if [[ $KRAFT_ADVERTISED_LISTENERS -eq 0 ]] 
then
sudo sed -i s/offsets.topic.replication.factor=1/offsets.topic.replication.factor=2/ /opt/kafka/config/kraft/server.properties
sudo sed -i s/transaction.state.log.replication.factor=1/transaction.state.log.replication.factor=2/ /opt/kafka/config/kraft/server.properties
sudo sed -i s/socket.receive.buffer.bytes=102400/socket.receive.buffer.bytes=1048576/ /opt/kafka/config/kraft/server.properties
sudo sed -i s/socket.send.buffer.bytes=102400/socket.send.buffer.bytes=1048576/ /opt/kafka/config/kraft/server.properties
sudo sed -i s/controller.quorum.voters=1@localhost:9093/controller.quorum.voters=1@$PRIVATE_IP_ADDRESS:9093/ /opt/kafka/config/kraft/server.properties
#sudo sed -i s/listeners=PLAINTEXT:\\/\\/:9092,CONTROLLER:\\/\\/:9093/listeners=SASL_SSL:\\/\\/$PRIVATE_IP_ADDRESS\\/:9092,INTERNAL:\\/\\/$PRIVATE_IP_ADDRESS:9094,CONTROLLER:\\/\\/$PRIVATE_IP_ADDRESS\\/:9093/ /opt/kafka/config/kraft/server.properties
# Note that the hostname here is optional, the absence of hostname represents binding to 0.0.0.0 i.e., all interfaces
sudo sed -i s/listeners=PLAINTEXT:\\/\\/:9092,CONTROLLER:\\/\\/:9093/listeners=CLIENT:\\/\\/:9092,CONTROLLER:\\/\\/:9093,BROKER:\\/\\/:9094/ /opt/kafka/config/kraft/server.properties
sudo sed -i s/inter.broker.listener.name=PLAINTEXT/inter.broker.listener.name=BROKER/ /opt/kafka/config/kraft/server.properties
sudo sed -i s/advertised.listeners=PLAINTEXT:\\/\\/localhost:9092,CONTROLLER:\\/\\/localhost:9093/advertised.listeners=CLIENT:\\/\\/$PUBLIC_IP_ADDRESS:9092,BROKER:\\/\\/$PRIVATE_IP_ADDRESS:9094/ /opt/kafka/config/kraft/server.properties
sudo sed -i s/listener.security.protocol.map=CONTROLLER:PLAINTEXT,PLAINTEXT:PLAINTEXT,SSL:SSL,SASL_PLAINTEXT:SASL_PLAINTEXT,SASL_SSL:SASL_SSL/listener.security.protocol.map=CLIENT:SASL_SSL,CONTROLLER:SASL_SSL,BROKER:SASL_SSL/ /opt/kafka/config/kraft/server.properties
sudo sh -c 'cat << EOF >> /opt/kafka/config/kraft/server.properties
client.bootstrap.servers=CONTROLLER://'$PRIVATE_IP_ADDRESS':9093
client.sasl.mechanism=SCRAM-SHA-256
client.security.protocol=SASL_SSL
client.sasl.jaas.config=org.apache.kafka.common.security.scram.ScramLoginModule required \
    username='$2' \
    password='$1';
# Producer
producer.bootstrap.servers=CONTROLLER://'$PRIVATE_IP_ADDRESS':9093
producer.sasl.mechanism=SCRAM-SHA-256
producer.security.protocol=SASL_SSL
producer.sasl.jaas.config=org.apache.kafka.common.security.scram.ScramLoginModule required \
  username='$2' \
  password='$1';
# Consumer
consumer.bootstrap.servers=CONTROLLER://'$PRIVATE_IP_ADDRESS':9093
consumer.group.id=testtopic-consumer-group
consumer.sasl.mechanism=SCRAM-SHA-256
consumer.security.protocol=SASL_SSL
consumer.sasl.jaas.config=org.apache.kafka.common.security.scram.ScramLoginModule required \
  username='$2' \
  password='$1';
EOF'
# sudo /opt/kafka/bin/kafka-acls.sh --bootstrap-server $PUBLIC_IP_ADDRESS:9092 --add --allow-principal "User:broker1" --operation ClusterAction --cluster
# sudo /opt/kafka/bin/kafka-acls.sh --bootstrap-server $PUBLIC_IP_ADDRESS:9092 --list --cluster
sudo systemctl daemon-reload
sudo systemctl enable kafka
sudo systemctl start kafka
sudo systemctl status kafka
sudo /opt/kafka/bin/kafka-topics.sh --create --bootstrap-server $PUBLIC_IP_ADDRESS:9092 --replication-factor 1 --partitions 3 --topic testtopic --if-not-exists 
#--command-config /opt/kafka/config/kraft/client.properties
sudo /opt/kafka/bin/kafka-topics.sh --bootstrap-server $PUBLIC_IP_ADDRESS:9092 --list 
#--command-config /opt/kafka/config/kraft/client.properties
echo 'SASL_SCRAM_PASSWORD username'$2' password:'$1''
sudo /opt/kafka/bin/kafka-configs.sh --bootstrap-server $PUBLIC_IP_ADDRESS:9092 --alter --add-config 'SCRAM-SHA-256=[password='$1']' --entity-type users --entity-name admin
# sudo /opt/kafka/bin/kafka-configs.sh --bootstrap-server $PRIVATE_IP_ADDRESS:9092 --alter --add-config 'SCRAM-SHA-256=[password='$1']' --entity-type users --entity-name broker
# sudo /opt/kafka/bin/kafka-configs.sh --bootstrap-server $PRIVATE_IP_ADDRESS:9092 --alter --add-config 'SCRAM-SHA-256=[password='$1']' --entity-type users --entity-name controller
# sudo /opt/kafka/bin/kafka-acls.sh --bootstrap-server $PRIVATE_IP_ADDRESS:9092 --add --allow-principal "User:admin" --operation ClusterAction --cluster
# sudo /opt/kafka/bin/kafka-acls.sh --bootstrap-server $PRIVATE_IP_ADDRESS:9092 --add --allow-principal "User:broker" --operation ClusterAction --cluster
# sudo /opt/kafka/bin/kafka-acls.sh --bootstrap-server $PRIVATE_IP_ADDRESS:9092 --add --allow-principal "User:controller" --operation ClusterAction --cluster
# sudo systemctl restart kafka
# sudo systemctl status kafka -l
# sudo /opt/kafka/bin/kafka-metadata-quorum.sh --bootstrap-controller $PRIVATE_IP_ADDRESS:9093 describe --status
fi

# cat /var/log/cloud-init-output.log
# cat /opt/kafka/logs/server.log
# cat /opt/kafka/config/kraft/server.properties
#sudo systemctl list-unit-files --type=service

# Create a topic if doesn't exists
#sudo /opt/kafka/bin/kafka-topics.sh --create --bootstrap-server $PUBLIC_IP_ADDRESS:9092 --replication-factor 1 --partitions 3 --topic testtopic --if-not-exists --command-config /opt/kafka/config/kraft/client.properties

# List all the existing topics
#sudo /opt/kafka/bin/kafka-topics.sh --bootstrap-server $PUBLIC_IP_ADDRESS:9092 --list --command-config /opt/kafka/config/kraft/client.properties

# sudo ss -tulnp | grep java
# tail -f /opt/kafka/logs/server.log
# curl ifconfig.me
# journalctl -u kafka -f

#sudo /opt/kafka/bin/kafka-configs.sh --bootstrap-server localhost:9092 --entity-type users --describe --entity-name admin
#ExecStartPre=sudo /opt/kafka/bin/kafka-storage.sh format --config /opt/kafka/config/kraft/server.properties --cluster-id $CLUSTER_ID --add-scram SCRAM-SHA-256=[name=${username},password=${password}]
#sudo /opt/kafka/bin/kafka-metadata-quorum.sh --bootstrap-server $PUBLIC_IP_ADDRESS:9092 --command-config config/client.properties describe --status
#sudo /opt/kafka/bin/kafka-topics.sh --bootstrap-server 34.250.196.150:9092 --list --command-config /opt/kafka/config/kraft/client.properties

# Consuming Message

#sudo /opt/kafka/bin/kafka-console-consumer.sh --bootstrap-server 34.250.196.150:9092 --topic testtopic --from-beginning --consumer.config /opt/kafka/config/kraft/client.properties

# Produce Messsage

#sudo /opt/kafka/bin/kafka-console-producer.sh --bootstrap-server 54.155.178.235:9092 --topic testtopic --producer.config /opt/kafka/config/kraft/client.properties
#sudo /opt/kafka/bin/kafka-topics.sh --bootstrap-server 34.250.196.150:9092 --list

#sudo /opt/kafka/bin/kafka-metadata-quorum.sh --bootstrap-controller 34.250.196.150:9092 describe --status
#sudo /opt/kafka/bin/kafka-topics.sh --bootstrap-server 172.31.30.39:9092 --list --command-config /opt/kafka/config/kraft/client.properties
#sudo /opt/kafka/bin/kafka-metadata-quorum.sh --bootstrap-server 54.78.163.240:9092 describe --status --command-config /opt/kafka/config/kraft/client.properties
#journalctl -xeu kafka.service
#sudo /opt/kafka/bin/kafka-acls.sh --bootstrap-server 54.78.163.240:9092 --add --allow-principal "User:broker1" --operation ClusterAction --cluster /opt/kafka/config/kraft/client.properties
#sudo /opt/kafka/bin/kafka-acls.sh --bootstrap-server 54.78.163.240:9092 --list --cluster
#cat /var/bin/kafka/logs/meta.properties


