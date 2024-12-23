#!/bin/bash


KRAFT_SERVER="/opt/kafka/config/kraft/server.properties"
PUBLIC_IP_ADDRESS=$(ec2-metadata --public-ipv4 | cut -d " " -f 2);

KRAFT_ADVERTISED_LISTENERS=$(cat $KRAFT_SERVER | grep -c "advertised.listeners=SASL_SSL://$PUBLIC_IP_ADDRESS:9092")
echo 'KRAFT_ADVERTISED_LISTENERS '$KRAFT_ADVERTISED_LISTENERS''
if [[ $KRAFT_ADVERTISED_LISTENERS -eq 0 ]] 
then
echo 'PUBLIC_IP_ADDRESS: '$PUBLIC_IP_ADDRESS''
#sudo sed -i s/log.dirs=\\/tmp\\/kraft-combined-logs/log.dirs=\\/var\\/log\\/kafka/ $KRAFT_SERVER
sudo sed -i s/num.partitions=1/num.partitions=3/ $KRAFT_SERVER
sudo sed -i s/offsets.topic.replication.factor=1/offsets.topic.replication.factor=2/ $KRAFT_SERVER
sudo sed -i s/transaction.state.log.replication.factor=1/transaction.state.log.replication.factor=2/ $KRAFT_SERVER
sudo sed -i s/socket.receive.buffer.bytes=102400/socket.receive.buffer.bytes=1048576/ $KRAFT_SERVER
sudo sed -i s/socket.send.buffer.bytes=102400/socket.send.buffer.bytes=1048576/ $KRAFT_SERVER
sudo sed -i s/controller.quorum.voters=1@localhost:9093/controller.quorum.voters=1@$PUBLIC_IP_ADDRESS:9093/ $KRAFT_SERVER
sudo sed -i s/listeners=PLAINTEXT:\\/\\/:9092,CONTROLLER:\\/\\/:9093/listeners=SASL_SSL:\\/\\/$PUBLIC_IP_ADDRESS:9092,CONTROLLER:\\/\\/$PUBLIC_IP_ADDRESS:9093/ $KRAFT_SERVER
sudo sed -i s/inter.broker.listener.name=PLAINTEXT/inter.broker.listener.name=SASL_SSL/ $KRAFT_SERVER
sudo sed -i s/advertised.listeners=PLAINTEXT:\\/\\/localhost:9092,CONTROLLER:\\/\\/localhost:9093/advertised.listeners=SASL_SSL:\\/\\/$PUBLIC_IP_ADDRESS:9092/ $KRAFT_SERVER
sudo sed -i s/listener.security.protocol.map=CONTROLLER:PLAINTEXT,PLAINTEXT:PLAINTEXT,SSL:SSL,SASL_PLAINTEXT:SASL_PLAINTEXT,SASL_SSL:SASL_SSL/listener.security.protocol.map=CONTROLLER:SASL_SSL,SSL:SSL,SASL_PLAINTEXT:SASL_PLAINTEXT,SASL_SSL:SASL_SSL/ $KRAFT_SERVER
fi

sudo systemctl daemon-reload
sudo systemctl restart kafka
sudo systemctl status kafka
sudo systemctl list-unit-files --type=service



