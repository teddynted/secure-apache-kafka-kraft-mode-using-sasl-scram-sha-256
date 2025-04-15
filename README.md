# Securing and Monitoring Kafka Kraft Mode Using SASL/SCRAM authentication

Secure and monitor your Amazon Linux 2023 EC2 self-hosted Apache Kafka using SASL/SCRAM

### Create Topic

```cli
/opt/kafka/bin/kafka-topics.sh --create --bootstrap-server <ec2-private-dns-name>:9092 --replication-factor 1 --partitions 3 --topic testtopic --if-not-exists --command-config /opt/kafka/config/kraft/admin.config
```


### List Topics

```cli
/opt/kafka/bin/kafka-topics.sh kafka-topics --bootstrap-server <ec2-private-dns-name>:9092 --list --command-config /opt/kafka/config/kraft/admin.config
```

### Consuming Message

```cli
sudo /opt/kafka/bin/kafka-console-consumer.sh --bootstrap-server <ec2-private-dns-name>:9092 --topic testtopic --from-beginning --consumer.config /opt/kafka/config/kraft/client.properties
```

### Produce Messsage

```cli
sudo /opt/kafka/bin/kafka-console-producer.sh --bootstrap-server <ec2-private-dns-name>:9092 --topic testtopic --producer.config /opt/kafka/config/kraft/client.properties


### Commands

#### Check that Kafka is running

```cli
ps aux | grep kafka.Kafka
```

### Validate TLS/SSL Configuration

```cli
openssl s_client -connect <broker-ip>:9092 -showcerts
```

### Verify Basic Connectivity

```cli
# Check if Kafka brokers are reachable
nc -zv <broker-ip> 9092
telnet <broker-ip> 9092
```

### Check Broker Logs

```cli
tail -f /opt/kafka/log/kafka/server.log | grep -i sasl
grep -i "authentication failed" /opt/kafka/log/kafka/server.log
```

### Check Listening Ports

```cli
sudo ss -tulnp | grep java
```