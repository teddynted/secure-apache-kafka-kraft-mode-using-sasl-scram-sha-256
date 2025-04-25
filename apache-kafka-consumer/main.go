package main

import (
	"context"
	"fmt"
	"log"

	"github.com/aws/aws-lambda-go/lambda"
	"github.com/aws/aws-sdk-go/aws"
	"github.com/aws/aws-sdk-go/aws/session"
	"github.com/aws/aws-sdk-go/service/sns"
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

var snsClient *sns.SNS

func init() {
	sess := session.Must(session.NewSession())
	snsClient = sns.New(sess)
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
	input := &sns.PublishInput{
		Message:  aws.String("Hello from Lambda triggered SNS!"),
		TopicArn: aws.String("arn:aws:sns:region:account-id:MySNSTopic"),
	}

	result, err := snsClient.Publish(input)
	if err != nil {
		log.Printf("Error publishing to SNS: %s", err)
	}

	fmt.Printf("Message sent to SNS: %s\n", *result.MessageId)
	return nil
}

func main() {
	lambda.Start(handleRequest)
}
