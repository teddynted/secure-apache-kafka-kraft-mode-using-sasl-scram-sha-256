package main

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"strings"

	"github.com/aws/aws-lambda-go/lambda"
	"github.com/aws/aws-sdk-go/aws"
	"github.com/aws/aws-sdk-go/aws/session"
	"github.com/aws/aws-sdk-go/service/ec2"
)

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
	Status             string `json:"Status"`
	Reason             string `json:"Reason"`
	PhysicalResourceId string `json:"PhysicalResourceId"`
	StackId            string `json:"StackId"`
	RequestId          string `json:"RequestId"`
	LogicalResourceId  string `json:"LogicalResourceId"`
	//Data               map[string]string `json:"Data"`
	Data string `json:"Data"`
}

func AwsRegion() string {

	return os.Getenv("AWS_REGION")
}

func GetApacheKakfaBrokers(client *ec2.EC2) (*ec2.DescribeInstancesOutput, error) {
	result, err := client.DescribeInstances(&ec2.DescribeInstancesInput{
		Filters: []*ec2.Filter{
			{
				Name: aws.String("instance-state-name"),
				Values: []*string{
					aws.String("running"),
				},
			},
			{
				Name:   aws.String("tag::Name"),
				Values: []*string{aws.String("*Apache*,*Kafka*")},
			},
		},
	})

	if err != nil {
		return nil, err
	}

	return result, err
}

func BootstrapServers() (string, error) {

	log.Println("Stopped an Instance...")

	sess, err := session.NewSessionWithOptions(session.Options{
		Config: aws.Config{
			Region: aws.String(AwsRegion()),
		},
	})

	if err != nil {
		fmt.Printf("Failed to initialize new session: %v", err)
	}

	ec2Client := ec2.New(sess)

	apacheKakfaBrokers, err := GetApacheKakfaBrokers(ec2Client)
	if err != nil {
		fmt.Printf("Couldnt retrieve bootstrap servers: %v", err)
	}

	var ips []string
	for _, reservation := range apacheKakfaBrokers.Reservations {
		for _, instance := range reservation.Instances {
			if instance.PublicIpAddress != nil {
				ips = append(ips, fmt.Sprintf("%s:9092", *instance.PublicIpAddress))
			}
		}
	}

	return strings.Join(ips, ", "), nil
}

func handler(event CloudFormationRequest) error {
	log.Println("Received CloudFormation event:", event)

	// Create your custom return value
	servers, _err := BootstrapServers()
	log.Println("Boostrap Servers:", servers)
	if _err != nil {
		return fmt.Errorf("couldnt retrieve bootstrap servers: %v", _err)
	}

	response := CloudFormationResponse{
		Status:             "SUCCESS",
		Reason:             "Custom resource creation successful",
		PhysicalResourceId: "custom-resource-id-123",
		StackId:            event.StackId,
		RequestId:          event.RequestId,
		LogicalResourceId:  event.LogicalResourceId,
		// Data: map[string]string{
		// 	"Value": servers,
		// },
		Data: servers,
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
