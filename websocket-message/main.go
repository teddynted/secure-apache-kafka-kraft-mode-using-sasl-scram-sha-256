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

func handler(ctx context.Context, event events.APIGatewayWebsocketProxyRequest) (events.APIGatewayProxyResponse, error) {
	db := dynamodb.New(session.Must(session.NewSession()))
	api := apigatewaymanagementapi.New(session.Must(session.NewSession()),
		aws.NewConfig().WithEndpoint(fmt.Sprintf("https://%s.execute-api.%s.amazonaws.com/%s",
			os.Getenv("API_ID"), os.Getenv("AWS_REGION"), os.Getenv("STAGE"))))

	connections, err := db.Scan(&dynamodb.ScanInput{
		TableName: aws.String(os.Getenv("TABLE_NAME")),
	})
	if err != nil {
		log.Println("Scan error:", err)
		return events.APIGatewayProxyResponse{StatusCode: 500}, err
	}

	for _, item := range connections.Items {
		connID := *item["connectionId"].S
		_, err := api.PostToConnection(&apigatewaymanagementapi.PostToConnectionInput{
			ConnectionId: aws.String(connID),
			Data:         []byte("Message from WebSocket handler"),
		})
		if err != nil {
			log.Printf("Failed to post to %s: %v", connID, err)
		}
	}

	return events.APIGatewayProxyResponse{StatusCode: 200}, nil
}

func main() {
	lambda.Start(handler)
}
