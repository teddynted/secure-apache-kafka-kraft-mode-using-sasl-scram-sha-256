package main

import (
	"context"
	"log"

	"github.com/aws/aws-lambda-go/lambda"
)

type KafkaEvent struct {
	EventSource    string              `json:"eventSource"`
	EventSourceARN string              `json:"eventSourceArn"`
	Records        map[string][]Record `json:"records"`
}

type Record struct {
	Partition string `json:"partition"`
	Offset    string `json:"offset"`
	Key       string `json:"key"`
	Value     string `json:"value"`
}

// Lambda triggered by Apache Kafka Event Source
func handleRequest(ctx context.Context, event KafkaEvent) error {
	log.Printf("Processing Kafka event from source: %s", event.EventSource)
	for topic, records := range event.Records {
		log.Printf("Topic: %s", topic)
		for _, record := range records {
			log.Printf("Partition: %s, Offset: %s, Key: %s, Value: %s", record.Partition, record.Offset, record.Key, record.Value)
		}
	}
	return nil
}

func main() {
	lambda.Start(handleRequest)
}
