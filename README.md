# Securing and Monitoring Kafka Kraft Mode Using SASL/SCRAM authentication

Secure and monitor your Amazon Linux 2023 EC2 self-hosted Apache Kafka using SASL/SCRAM

### List Topics

```cli
./bin/kafka-topics.sh kafka-topics --bootstrap-server localhost:9092 --list --command-config config/kraft/admin.config
```

### Create Topic

```cli
./bin/kafka-topics.sh --create --bootstrap-server localhost:9092 --replication-factor 1 --partitions 3 --topic testtopic --if-not-exists --command-config config/kraft/admin.config
```

### Run on Your Local

```cli
chmod +x run.sh
./run.sh
```