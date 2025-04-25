package main

import (
	"context"
	"fmt"

	"github.com/aws/aws-lambda-go/events"
	"github.com/aws/aws-lambda-go/lambda"
)

// HandleRequest will be triggered by an SNS message
func HandleRequest(ctx context.Context, snsEvent events.SNSEvent) {
	for _, record := range snsEvent.Records {
		// Process the SNS message
		fmt.Printf("Received message: %s\n", record.SNS.Message)
	}
}

func main() {
	// Start Lambda function
	lambda.Start(HandleRequest)
}
