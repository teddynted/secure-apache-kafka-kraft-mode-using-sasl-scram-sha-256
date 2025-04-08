# Securing and Monitoring Kafka Kraft Mode Using SASL/SCRAM authentication

Secure and monitor your Amazon Linux 2023 EC2 self-hosted Apache Kafka using SASL/SCRAM

### Create Topic

```cli
/opt/kafka/bin/kafka-topics.sh --create --bootstrap-server <ec2-public-ip-address>:9092 --replication-factor 1 --partitions 3 --topic testtopic --if-not-exists --command-config /opt/kafka/config/kraft/admin.config
```


### List Topics

```cli
/opt/kafka/bin/kafka-topics.sh kafka-topics --bootstrap-server <ec2-public-ip-address>:9092 --list --command-config /opt/kafka/config/kraft/admin.config
```

### Commands

#### Check that Kafka is running

```cli
ps aux | grep kafka.Kafka
```

### Validate TLS/SSL Configuration

```cli
openssl s_client -connect <broker-ip>:9092 -showcerts
```

```cli
tail -f /opt/kafka/logs/server.log
```