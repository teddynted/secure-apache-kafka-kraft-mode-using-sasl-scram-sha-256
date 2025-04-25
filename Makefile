build:
	echo "Building lambda binaries"
	env GOOS=linux GOARCH=arm64 go build -o build/start-instances/bootstrap start-instances/main.go
	env GOOS=linux GOARCH=arm64 go build -o build/stop-instances/bootstrap stop-instances/main.go
	env GOOS=linux GOARCH=arm64 go build -o build/apache-kafka-consumer/bootstrap apache-kafka-consumer/main.go

zip:
	zip -j build/start-instances.zip build/start-instances/bootstrap
	zip -j build/stop-instances.zip build/stop-instances/bootstrap
	zip -j build/apache-kafka-consumer.zip build/apache-kafka-consumer/bootstrap