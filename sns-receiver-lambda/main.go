package main

import (
	"context"
	"fmt"

	"github.com/aws/aws-lambda-go/events"
	"github.com/aws/aws-lambda-go/lambda"
	//"github.com/gorilla/websocket"
)

// HandleRequest will be triggered by an SNS message
func HandleRequest(ctx context.Context, snsEvent events.SNSEvent) {
	for _, record := range snsEvent.Records {
		// Process the SNS message
		fmt.Printf("Received message: %s\n", record.SNS.Message)
	}
	connectAndSendMessage()
}

func connectAndSendMessage() {
	// websocketURL := "wss://<your-api-id>.execute-api.<region>.amazonaws.com/<stage>"

	// u := url.URL{Scheme: "wss", Host: websocketURL[6:], Path: "/"} // remove wss://

	// log.Printf("Connecting to %s", u.String())

	// dialer := websocket.Dialer{
	// 	HandshakeTimeout: 5 * time.Second,
	// }

	// conn, _, err := dialer.Dial(u.String(), nil)
	// if err != nil {
	// 	log.Fatalf("Failed to connect: %v", err)
	// }
	// defer conn.Close()

	// log.Println("Connected to WebSocket")

	// // Send a message
	// err = conn.WriteJSON(map[string]string{"action": "sendMessage", "data": "Hello from Go client!"})
	// if err != nil {
	// 	log.Printf("Write error: %v", err)
	// }

	// // Read response (if expected)
	// _, message, err := conn.ReadMessage()
	// if err != nil {
	// 	log.Printf("Read error: %v", err)
	// } else {
	// 	log.Printf("Received: %s", message)
	// }
}

func main() {
	// Start Lambda function
	lambda.Start(HandleRequest)
}
