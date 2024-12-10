### List Topics

```cli
./bin/kafka-topics.sh --list --bootstrap-server localhost:9092 --command-config config/kraft/admin.config
./bin/kafka-topics.sh kafka-topics --bootstrap-server localhost:9092 --list --command-config config/kraft/admin.config
./bin/kafka-topics.sh --create --bootstrap-server localhost:9092 --replication-factor 1 --partitions 3 --topic testtopic --if-not-exists --command-config config/kraft/admin.config
./bin/kafka-metadata-quorum.sh --bootstrap-controller localhost:9093 describe --status
./bin/kafka-topics.sh --create --bootstrap-server localhost:9092 --replication-factor 1 --partitions 3 --topic testtopic --if-not-exists --command-config config/kraft/jaas.config
```
