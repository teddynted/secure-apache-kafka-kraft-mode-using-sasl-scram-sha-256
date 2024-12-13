#!/bin/bash

export PATH="/usr/bin:$PATH"
PUBLIC_IP_ADDRESS=$(ec2-metadata --public-ipv4 | cut -d " " -f 2);

echo 'PUBLIC_IP_ADDRESS: '$PUBLIC_IP_ADDRESS''
sudo sed -i s/log.dirs=\\/tmp\\/kraft-combined-logs/log.dirs=config\\/kraft\\/logs/ /opt/kafka/config/kraft/server.properties
sudo sed -i s/num.partitions=1/num.partitions=3/ /opt/kafka/config/kraft/server.properties
sudo sed -i s/offsets.topic.replication.factor=1/offsets.topic.replication.factor=2/ /opt/kafka/config/kraft/server.properties
sudo sed -i s/transaction.state.log.replication.factor=1/transaction.state.log.replication.factor=2/ /opt/kafka/config/kraft/server.properties
sudo sed -i s/socket.receive.buffer.bytes=102400/socket.receive.buffer.bytes=1048576/ /opt/kafka/config/kraft/server.properties
sudo sed -i s/socket.send.buffer.bytes=102400/socket.send.buffer.bytes=1048576/ /opt/kafka/config/kraft/server.properties
sudo sed -i s/controller.quorum.voters=1@localhost:9093/controller.quorum.voters=1@$PUBLIC_IP_ADDRESS:9093/ /opt/kafka/config/kraft/server.properties
sudo sed -i s/listeners=PLAINTEXT:\\/\\/:9092,CONTROLLER:\\/\\/:9093/listeners=SASL_SSL:\\/\\/$PUBLIC_IP_ADDRESS:9092,CONTROLLER:\\/\\/$PUBLIC_IP_ADDRESS:9093/ /opt/kafka/config/kraft/server.properties
sudo sed -i s/inter.broker.listener.name=PLAINTEXT/inter.broker.listener.name=SASL_SSL/ /opt/kafka/config/kraft/server.properties
sudo sed -i s/advertised.listeners=PLAINTEXT:\\/\\/localhost:9092,CONTROLLER:\\/\\/localhost:9093/advertised.listeners=SASL_SSL:\\/\\/$PUBLIC_IP_ADDRESS:9092/ /opt/kafka/config/kraft/server.properties
sudo sed -i s/listener.security.protocol.map=CONTROLLER:PLAINTEXT,PLAINTEXT:PLAINTEXT,SSL:SSL,SASL_PLAINTEXT:SASL_PLAINTEXT,SASL_SSL:SASL_SSL/listener.security.protocol.map=CONTROLLER:SASL_SSL,SSL:SSL,SASL_PLAINTEXT:SASL_PLAINTEXT,SASL_SSL:SASL_SSL/ /opt/kafka/config/kraft/server.properties

# Prometheus
sudo useradd --no-create-home prometheus
sudo mkdir /etc/prometheus
sudo mkdir /var/lib/prometheus
wget https://github.com/prometheus/prometheus/releases/download/v3.0.1/prometheus-3.0.1.linux-amd64.tar.gz
tar xzf prometheus-3.0.1.linux-amd64.tar.gz
sudo cp prometheus-3.0.1.linux-amd64/prometheus /usr/local/bin
sudo cp prometheus-3.0.1.linux-amd64/promtool /usr/local/bin/
sudo cp -r prometheus-3.0.1.linux-amd64/consoles /etc/prometheus
sudo cp -r prometheus-3.0.1.linux-amd64/console_libraries /etc/prometheussudo cp prometheus-3.0.1.linux-amd64/promtool /usr/local/bin/
rm -rf prometheus-3.0.1.linux-amd64.tar.gz prometheus-3.0.1.linux-amd64
cat /opt/prometheus/prometheus.yml
sudo sh -c 'cat << EOF >> /opt/prometheus/prometheus.yml
              
  - job_name: 'kafka'
    static_configs:
    - targets: ['$PUBLIC_IP_ADDRESS:7075']
EOF'

sudo cat <<EOF > /etc/systemd/system/prometheus.service
[Unit]
Description=Prometheus Server
Documentation=https://prometheus.io/docs/introduction/overview/
After=network-online.target
            
[Service]
User=ec2-user
Restart=on-failure
ExecStart=sudo /opt/prometheus/prometheus --config.file=/opt/prometheus/prometheus.yml --storage.tsdb.path=/opt/prometheus/data --storage.tsdb.retention.time=30d

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl restart kafka
sudo systemctl enable prometheus
sudo systemctl start prometheus
sudo systemctl status prometheus
sudo systemctl list-unit-files --type=service

# export COUNTRY=ZA
# export STATE=Gauteng
# export ORGANIZATION_UNIT=PX
# export CITY=Johannesburg
# export PASSWORD=${password}



