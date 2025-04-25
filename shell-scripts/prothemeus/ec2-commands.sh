#!/bin/bash

KAFKA_BOOTSTRAP_SERVER=$1
KAFKA_BOOTSTRAP_SERVER_TWO=$2
KAFKA_BOOTSTRAP_SERVER_THREE=$3

echo "KAFKA_BOOTSTRAP_SERVER $KAFKA_BOOTSTRAP_SERVER"
echo "KAFKA_BOOTSTRAP_SERVER_TWO $KAFKA_BOOTSTRAP_SERVER_TWO"
echo "KAFKA_BOOTSTRAP_SERVER_THREE $KAFKA_BOOTSTRAP_SERVER_THREE"
echo "Setup Prometheus Configuration"

sudo cat /etc/prometheus/prometheus.yml

sudo systemctl daemon-reload
sudo systemctl start prometheus
sudo systemctl status prometheus

#http://<prometheus-ip>:9090/graph