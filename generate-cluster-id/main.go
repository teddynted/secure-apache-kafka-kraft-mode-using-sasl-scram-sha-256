package main

import (
	"context"
	"encoding/json"
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

func sendResponse(req CloudFormationRequest, status string, data map[string]string) {
	resp := CloudFormationResponse{
		Status:             status,
		Reason:             "See logs in CloudWatch",
		PhysicalResourceId: req.PhysicalResourceId,
		StackId:            req.StackId,
		RequestId:          req.RequestId,
		LogicalResourceId:  req.LogicalResourceId,
		Data:               data,
	}

	body, err := json.Marshal(resp)
	if err != nil {
		log.Println("Failed to marshal response:", err)
		return
	}

	httpReq, err := http.NewRequest("PUT", req.ResponseURL, nil)
	if err != nil {
		log.Println("Failed to create HTTP request:", err)
		return
	}

	httpReq.Body = http.NoBody
	httpReq.Header.Set("Content-Type", "")
	httpReq.ContentLength = int64(len(body))

	client := &http.Client{}
	_, err = client.Do(httpReq)
	if err != nil {
		log.Println("Failed to send response:", err)
	}
}

func handler(ctx context.Context, req CloudFormationRequest) {
	log.Println("Received event:", req.RequestType)

	uid := uuid.New().String()
	log.Println("Generated UUID:", uid)

	sendResponse(req, "SUCCESS", map[string]string{"Value": uid})
}

func main() {
	lambda.Start(handler)
}
