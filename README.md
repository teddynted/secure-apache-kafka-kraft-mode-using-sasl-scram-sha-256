# Securing and Monitoring Kafka Kraft Mode Using SASL/SCRAM authentication

### List Topics

```cli
./bin/kafka-topics.sh kafka-topics --bootstrap-server localhost:9092 --list --command-config config/kraft/admin.config
```

### Create Topic

```cli
./bin/kafka-topics.sh --create --bootstrap-server localhost:9092 --replication-factor 1 --partitions 3 --topic testtopic --if-not-exists --command-config config/kraft/admin.config
```