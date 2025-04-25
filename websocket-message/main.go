package main

import (
	"context"
	"fmt"

	"github.com/aws/aws-lambda-go/events"
	"github.com/aws/aws-lambda-go/lambda"
)

func handler(ctx context.Context, request events.APIGatewayWebsocketProxyRequest) (events.APIGatewayProxyResponse, error) {
	fmt.Printf("Message from %s: %s\n", request.RequestContext.ConnectionID, request.Body)
	return events.APIGatewayProxyResponse{StatusCode: 200}, nil
}
func main() {
	lambda.Start(handler)
}
