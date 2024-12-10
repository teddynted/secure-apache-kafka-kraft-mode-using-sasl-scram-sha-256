HOST_NAME=localhost
PASS_WORD=Passw0rd123
USER_NAME=admin
DIR="config/certs"
JAAS_CONFIG="config/kraft/jaas.config"
ADMIN_CONFIG="config/kraft/admin.config"
KRAFT_LOGS="config/kraft/logs"
KRAFT_SERVER="config/kraft/server.properties"

rm -rf $JAAS_CONFIG $ADMIN_CONFIG $DIR
git checkout $KRAFT_SERVER

export KAFKA_HEAP_OPTS="-Xms1G -Xmx1G"
export COUNTRY="ZA"
export STATE="GAUTENG"
export ORGANIZATION_UNIT="PIXVENTIVE"
export CITY="Johannesburg"
export PASSWORD=$PASS_WORD

if [ -d "$DIR" ]; then
  echo 'Directory '$DIR' exists.'
else
  mkdir $DIR
  cd $DIR
  git clone https://github.com/confluentinc/confluent-platform-security-tools.git .
  echo 'KAFKA_HEAP_OPTS '$KAFKA_HEAP_OPTS''
  echo 'PASSWORD '$PASSWORD''
  chmod +x kafka-generate-ssl-automatic.sh kafka-generate-ssl.sh
  ./kafka-generate-ssl-automatic.sh
  ls -l
  cd ../..
fi

if [ -e "$JAAS_CONFIG" ]; then
    echo 'File '$JAAS_CONFIG' exists.'
else
    sudo touch $JAAS_CONFIG
    sudo cat <<EOF > $JAAS_CONFIG
KafkaServer {
    org.apache.kafka.common.security.scram.ScramLoginModule required username=$USER_NAME password=$PASS_WORD;
};
EOF
fi

if [ -e "$ADMIN_CONFIG" ]; then
    echo 'File '$ADMIN_CONFIG' exists.'
else
    sudo touch $ADMIN_CONFIG
    sudo cat <<EOF > $ADMIN_CONFIG
security.protocol=SASL_SSL
ssl.truststore.location=config/certs/truststore/kafka.truststore.jks
ssl.truststore.password=$PASS_WORD
sasl.mechanism=SCRAM-SHA-256
ssl.endpoint.identification.algorithm=
sasl.jaas.config=org.apache.kafka.common.security.scram.ScramLoginModule required username=$USER_NAME password=$PASS_WORD;
EOF
fi

# Kraft Configuration
KRAFT_ADVERTISED_LISTENERS=$(cat $KRAFT_SERVER | grep -c "advertised.listeners=PLAINTEXT://:9092,CONTROLLER://:9093")
KRAFT_LISTENERS=$(cat $KRAFT_SERVER | grep -c "listeners=PLAINTEXT://:9092,CONTROLLER://:9093")
echo $KRAFT_LISTENERS
echo $KRAFT_ADVERTISED_LISTENERS
if [[ $KRAFT_LISTENERS -eq 1 ]] 
then
    echo "Configuring Kraft 🚀"
    sudo rm -rf $KRAFT_LOGS
    sudo mkdir $KRAFT_LOGS
    sudo sed -i'' -e s/log.dirs=\\/tmp\\/kraft-combined-logs/log.dirs=config\\/kraft\\/logs/g $KRAFT_SERVER
    sudo sed -i'' -e s/num.partitions=1/num.partitions=3/ $KRAFT_SERVER
    sudo sed -i'' -e s/offsets.topic.replication.factor=1/offsets.topic.replication.factor=2/ $KRAFT_SERVER
    sudo sed -i'' -e s/transaction.state.log.replication.factor=1/transaction.state.log.replication.factor=2/ $KRAFT_SERVER
    sudo sed -i'' -e s/socket.receive.buffer.bytes=102400/socket.receive.buffer.bytes=1048576/ $KRAFT_SERVER
    sudo sed -i'' -e s/socket.send.buffer.bytes=102400/socket.send.buffer.bytes=1048576/ $KRAFT_SERVER
    sudo sed -i'' -e s/controller.quorum.voters=1@localhost:9093/controller.quorum.voters=1@$HOST_NAME:9093/ $KRAFT_SERVER
    sudo sed -i'' -e s/listeners=PLAINTEXT:\\/\\/:9092,CONTROLLER:\\/\\/:9093/listeners=SASL_SSL:\\/\\/localhost:9092,CONTROLLER:\\/\\/localhost:9093/ $KRAFT_SERVER
    sudo sed -i'' -e s/inter.broker.listener.name=PLAINTEXT/inter.broker.listener.name=SASL_SSL/ $KRAFT_SERVER
    sudo sed -i'' -e s/advertised.listeners=PLAINTEXT:\\/\\/localhost:9092,CONTROLLER:\\/\\/localhost:9093/advertised.listeners=SASL_SSL:\\/\\/localhost:9092/ $KRAFT_SERVER
    sudo sed -i'' -e s/listener.security.protocol.map=CONTROLLER:PLAINTEXT,PLAINTEXT:PLAINTEXT,SSL:SSL,SASL_PLAINTEXT:SASL_PLAINTEXT,SASL_SSL:SASL_SSL/listener.security.protocol.map=CONTROLLER:SASL_SSL,SSL:SSL,SASL_PLAINTEXT:SASL_PLAINTEXT,SASL_SSL:SASL_SSL/ $KRAFT_SERVER
    sudo sh -c 'cat << EOF >> '$KRAFT_SERVER'
sasl.enabled.mechanisms=SASL_PLAINTEXT,SCRAM-SHA-256,SCRAM-SHA-512,PLAIN,SASL_SSL
sasl.mechanism.controller.protocol=SCRAM-SHA-256
sasl.mechanism.inter.broker.protocol=SASL_SSL
ssl.client.auth=required
ssl.truststore.location=config/certs/truststore/kafka.truststore.jks
ssl.truststore.type=PKCS12
ssl.truststore.password='$PASS_WORD'
ssl.keystore.location=config/certs/keystore/kafka.keystore.jks
ssl.keystore.type=PKCS12
ssl.keystore.password='$PASS_WORD'
ssl.key.password='$PASS_WORD'
ssl.endpoint.identification.algorithm=
authorizer.class.name=org.apache.kafka.metadata.authorizer.StandardAuthorizer
allow.everyone.if.no.acl.found=false
super.users=User:admin
delete.topic.enable=true
default.replication.factor=2
min.insync.replicas=2
auto.create.topics.enable=true
unclean.leader.election.enable=false
log4j.logger.org.apache.kafka.common.network.SslTransportLayer=DEBUG
log4j.logger.org.apache.kafka.common.security.ssl.SslFactory=DEBUG
EOF'
    KAFKA_CLUSTER_ID="$(bin/kafka-storage.sh random-uuid)"
    ./bin/kafka-storage.sh format --config $KRAFT_SERVER --cluster-id $KAFKA_CLUSTER_ID --add-scram SCRAM-SHA-256=[name=$USER_NAME,password=$PASS_WORD]
    echo "Configuration Done ✅"
fi

# KAFKA_CLUSTER_ID="$(bin/kafka-storage.sh random-uuid)"
# echo $KAFKA_CLUSTER_ID
# ./bin/kafka-storage.sh format --config $KRAFT_SERVER --cluster-id $KAFKA_CLUSTER_ID --add-scram SCRAM-SHA-256=[name=$USER_NAME,password=$PASS_WORD]
export KAFKA_OPTS="-Djava.security.auth.login.config=config/kraft/jaas.config"
./bin/kafka-server-start.sh config/kraft/server.properties