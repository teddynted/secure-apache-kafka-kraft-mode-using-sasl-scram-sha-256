# Securing and Monitoring Apache Kafka Kraft Mode Using SASL/SCRAM authentication

Secure and monitor your Amazon Linux 2023 EC2 self-hosted Apache Kafka using SASL/SCRAM

## Pre-requisites

- Kafka version: 3.5+ (with KRaft mode support)
- Mode: KRaft (no Zookeeper)
- Nodes: Multiple EC2 instances for controller and brokers
- Auth: SASL/SCRAM
- Clients: External (from public internet or other networks)

## Apache and Amazon Linux CLI Commands

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
sudo /opt/kafka/bin/kafka-console-consumer.sh --bootstrap-server <ec2-private-dns-name>:9092 --topic testtopic --group test-group --consumer.config /opt/kafka/config/kraft/ssl-consumer.properties --from-beginning
```

### Produce Messsage

```cli
sudo /opt/kafka/bin/kafka-console-producer.sh --bootstrap-server <ec2-private-dns-name>:9092 --topic testtopic --producer.config /opt/kafka/config/kraft/client.properties
```

### Add a new ACL user

```cli
sudo /opt/kafka/bin/kafka-configs.sh --bootstrap-server <ec2-private-dns-name>:9092 --command-config /opt/kafka/config/kraft/client.properties --alter --add-config "SCRAM-SHA-256=[password='p@ssw0rd']" --entity-type users --entity-name admin
```

### Allow principal

```cli
sudo /opt/kafka/bin/kafka-acls.sh --bootstrap-server <ec2-private-dns-name>:9092 --command-config /opt/kafka/config/kraft/client.properties --add --allow-principal "User:admin" --operation ClusterAction --cluster
```

### Create a Kafka group ID

```cli
sudo /opt/kafka/bin/kafka-console-consumer.sh --bootstrap-server ip-172-31-31-253.eu-west-1.compute.internal:9092 --topic testtopic --group my-scram-group --consumer.config /opt/kafka/config/kraft/client.properties
```

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

## Best Practices

### Kafka

- Local Dev: 1 replication factor
- Production: 3 replication factor, for high availability  (have at least ec2 instances)

### AWS

- Use Elastic IP for you Kafka broker so the public IP remains static and doesn't change when the EC@ instance restarts

## Terms

- **SSL (Secure Sockets Layer)**: Encrypts data between two parties (e.g. Kafka client and broker)
- **SCRAM (Salted Challenge Response Authentication Mechanism)**: stores SCRAM credentials with the salt.
- **SASL (Simple Authentication and Security Layer)**: A framework that enables secure authentication between clients and brokers using various mechanisms like GSSAPI(Kerberos), Plain, SCRAM, and OAUTHBEARER.
- **KRaft (Mode)**: let's Kafka manage it's own data without needing Zookeeper. This makes the entire setup simpler and more efficient.
