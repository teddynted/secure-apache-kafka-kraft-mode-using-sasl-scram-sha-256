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
	"github.com/aws/aws-sdk-go/service/ec2"
)

func AwsRegion() string {

	return os.Getenv("AWS_REGION")
}

// Associate an Elastic IP with an EC2 instance
func AssociateElasticIP(client *ec2.EC2, instanceID string) {
	log.Println("Associating Elastic IP...")
	eipResp, err := client.DescribeAddresses(&ec2.DescribeAddressesInput{
		Filters: []*ec2.Filter{
			{
				Name: aws.String("instance-id"),
				Values: []*string{
					aws.String(instanceID),
				},
			},
		},
	})
	if err != nil {
		log.Fatalf("failed to describe Elastic IPs: %v", err)
	}
	fmt.Print(eipResp)
	log.Print(*eipResp)
	// allocationID := *eipResp.Addresses[0].AllocationId
	// input := &ec2.AssociateAddressInput{
	// 	InstanceId:   aws.String(instanceID),
	// 	AllocationId: aws.String(allocationID),
	// }
	// fmt.Print(input)
	// result, err := client.AssociateAddress(input)
	// if err != nil {
	// 	log.Fatalf("failed to associate addresses, %v", err)
	// }
	// fmt.Printf("Elastic IP associated successfully! Association ID: %s\n", *result.AssociationId)
}

func GetStoppedInstances(client *ec2.EC2) (*ec2.DescribeInstancesOutput, error) {
	result, err := client.DescribeInstances(&ec2.DescribeInstancesInput{
		Filters: []*ec2.Filter{
			{
				Name: aws.String("instance-state-name"),
				Values: []*string{
					aws.String("stopped"),
				},
			},
		},
	})

	if err != nil {
		return nil, err
	}

	return result, err
}

func StartInstance(client *ec2.EC2, instanceId string) error {
	_, err := client.StartInstances(&ec2.StartInstancesInput{
		InstanceIds: []*string{&instanceId},
	})
	return err
}

func main() {
	lambda.Start(handler)
}

func handler(_ctx context.Context, request events.APIGatewayProxyRequest) (events.APIGatewayProxyResponse, error) {
	log.Println("Starting an Instance...")

	sess, err := session.NewSessionWithOptions(session.Options{
		Config: aws.Config{
			Region: aws.String(AwsRegion()),
		},
	})

	if err != nil {
		fmt.Printf("Failed to initialize new session: %v", err)
	}

	ec2Client := ec2.New(sess)
	runningInstances, err := GetStoppedInstances(ec2Client)
	if err != nil {
		fmt.Printf("Couldn't retrieve stopped instances: %v", err)
	}
	for _, reservation := range runningInstances.Reservations {
		for _, instance := range reservation.Instances {
			fmt.Printf("Found stopped instance: %s\n", *instance.InstanceId)
			err = StartInstance(ec2Client, *instance.InstanceId)
			if err != nil {
				fmt.Printf("Couldn't start instance: %v", err)
			}
			AssociateElasticIP(ec2Client, *instance.InstanceId)

		}
	}

	response := events.APIGatewayProxyResponse{
		StatusCode: 200,
	}

	return response, nil
}
