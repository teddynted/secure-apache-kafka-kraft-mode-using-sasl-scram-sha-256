build:
	echo "Building lambda binaries"
	env GOOS=linux GOARCH=arm64 go build -o build/start-instances/bootstrap start-instances/main.go
	env GOOS=linux GOARCH=arm64 go build -o build/stop-instances/bootstrap stop-instances/main.go
	env GOOS=linux GOARCH=arm64 go build -o build/apache-kafka-consumer/bootstrap apache-kafka-consumer/main.go
	env GOOS=linux GOARCH=arm64 go build -o build/sns-receiver-lambda/bootstrap sns-receiver-lambda/main.go
	env GOOS=linux GOARCH=arm64 go build -o build/websocket-connect/bootstrap websocket-connect/main.go
	env GOOS=linux GOARCH=arm64 go build -o build/websocket-disconnect/bootstrap websocket-disconnect/main.go
	env GOOS=linux GOARCH=arm64 go build -o build/websocket-message/bootstrap websocket-message/main.go
	env GOOS=linux GOARCH=arm64 go build -o build/generate-cluster-id/bootstrap generate-cluster-id/main.go
	env GOOS=linux GOARCH=arm64 go build -o build/fetch-nodes-ip/bootstrap fetch-nodes-ip/main.go

zip:
	zip -j build/start-instances.zip build/start-instances/bootstrap
	zip -j build/stop-instances.zip build/stop-instances/bootstrap
	zip -j build/apache-kafka-consumer.zip build/apache-kafka-consumer/bootstrap
	zip -j build/sns-receiver-lambda.zip build/sns-receiver-lambda/bootstrap
	zip -j build/websocket-connect.zip build/websocket-connect/bootstrap
	zip -j build/websocket-disconnect.zip build/websocket-disconnect/bootstrap
	zip -j build/websocket-message.zip build/websocket-message/bootstrap
	zip -j build/generate-cluster-id.zip build/generate-cluster-id/bootstrap
	zip -j build/fetch-nodes-ip.zip build/fetch-nodes-ip/bootstrap