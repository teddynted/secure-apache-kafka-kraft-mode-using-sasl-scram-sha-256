package main

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"

	"github.com/aws/aws-lambda-go/lambda"
	"github.com/google/uuid"
)

// CloudFormationRequest represents the request sent by CloudFormation
type CloudFormationRequest struct {
	RequestType        string                 `json:"RequestType"`
	ResponseURL        string                 `json:"ResponseURL"`
	StackId            string                 `json:"StackId"`
	RequestId          string                 `json:"RequestId"`
	ResourceType       string                 `json:"ResourceType"`
	LogicalResourceId  string                 `json:"LogicalResourceId"`
	PhysicalResourceId string                 `json:"PhysicalResourceId"`
	ResourceProperties map[string]interface{} `json:"ResourceProperties"`
}

type CloudFormationResponse struct {
	Status             string            `json:"Status"`
	Reason             string            `json:"Reason"`
	PhysicalResourceId string            `json:"PhysicalResourceId"`
	StackId            string            `json:"StackId"`
	RequestId          string            `json:"RequestId"`
	LogicalResourceId  string            `json:"LogicalResourceId"`
	Data               map[string]string `json:"Data"`
}

func handler(event CloudFormationRequest) error {
	log.Println("Received CloudFormation event:", event)

	// Create your custom return value
	uid := uuid.New().String()
	log.Println("Generated UUID:", uid)

	response := CloudFormationResponse{
		Status:             "SUCCESS",
		Reason:             "Custom resource creation successful",
		PhysicalResourceId: "custom-resource-id-123",
		StackId:            event.StackId,
		RequestId:          event.RequestId,
		LogicalResourceId:  event.LogicalResourceId,
		Data: map[string]string{
			"Value": uid,
		},
	}

	responseBody, err := json.Marshal(response)
	if err != nil {
		return fmt.Errorf("failed to marshal response: %v", err)
	}

	req, err := http.NewRequest("PUT", event.ResponseURL, bytes.NewReader(responseBody))
	if err != nil {
		return fmt.Errorf("failed to create HTTP request: %v", err)
	}
	req.Header.Set("Content-Type", "")
	req.ContentLength = int64(len(responseBody))

	client := &http.Client{}
	resp, err := client.Do(req)
	if err != nil {
		return fmt.Errorf("failed to send response to CFN: %v", err)
	}
	defer func() {
		if cerr := resp.Body.Close(); cerr != nil {
			// log or handle close error
			fmt.Printf("error closing response body: %v\n", cerr)
		}
	}()

	body, _ := io.ReadAll(resp.Body)
	log.Printf("CFN response status: %s, body: %s", resp.Status, string(body))

	return nil
}

func main() {
	lambda.Start(handler)
}
