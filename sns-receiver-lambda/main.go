package main

import (
	"context"
	"fmt"
	"log"
	"os"

	"github.com/aws/aws-lambda-go/events"
	"github.com/aws/aws-lambda-go/lambda"
	"github.com/aws/aws-sdk-go/aws"
	"github.com/aws/aws-sdk-go/aws/session"
	"github.com/aws/aws-sdk-go/service/apigatewaymanagementapi"
	"github.com/aws/aws-sdk-go/service/dynamodb"
)

// HandleRequest will be triggered by an SNS message
func HandleRequest(ctx context.Context, snsEvent events.SNSEvent) {
	for _, record := range snsEvent.Records {
		// Process the SNS message
		fmt.Printf("Received message: %s\n", record.SNS.Message)
	}
}

func SendCustomMessage(ctx context.Context) error {
	db := dynamodb.New(session.Must(session.NewSession()))
	api := apigatewaymanagementapi.New(session.Must(session.NewSession()),
		aws.NewConfig().WithEndpoint(*aws.String(
			os.Getenv("REST_API_ENDPOINT_URI"))))

	connections, err := db.Scan(&dynamodb.ScanInput{
		TableName: aws.String(os.Getenv("TABLE_NAME")),
	})
	if err != nil {
		log.Println("Scan error:", err)
		return err
	}

	for _, item := range connections.Items {
		connID := *item["connectionId"].S
		_, err := api.PostToConnection(&apigatewaymanagementapi.PostToConnectionInput{
			ConnectionId: aws.String(connID),
			Data:         []byte("Triggered from another Lambda"),
		})
		if err != nil {
			log.Printf("Failed to send to %s: %v", connID, err)
		}
	}

	return err
}

func main() {
	// Start Lambda function
	lambda.Start(HandleRequest)
}
