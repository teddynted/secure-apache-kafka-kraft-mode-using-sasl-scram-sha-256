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

func StopInstance(client *ec2.EC2, instanceId string) error {
	_, err := client.StopInstances(&ec2.StopInstancesInput{
		InstanceIds: []*string{&instanceId},
	})
	return err
}

func GetRunningInstances(client *ec2.EC2) (*ec2.DescribeInstancesOutput, error) {
	result, err := client.DescribeInstances(&ec2.DescribeInstancesInput{
		Filters: []*ec2.Filter{
			{
				Name: aws.String("instance-state-name"),
				Values: []*string{
					aws.String("running"),
				},
			},
		},
	})

	if err != nil {
		return nil, err
	}

	return result, err
}

func main() {
	lambda.Start(handler)
}

func DisassociateAndReleaseElasticIP(client *ec2.EC2) (*ec2.DescribeAddressesOutput, error) {
	log.Println("Disassociate and release Elastic IP...")
	result, err := client.DescribeAddresses(&ec2.DescribeAddressesInput{})
	if err != nil {
		log.Fatalf("failed to describe addresses, %v", err)
	}
	for _, address := range result.Addresses {
		// Disassociate if associated
		if address.AssociationId != nil {
			fmt.Printf("Disassociating EIP: %v", address.PublicIp)
			fmt.Printf("Disassociating EIP: %s\n", *address.PublicIp)
			_, err := client.DisassociateAddress(&ec2.DisassociateAddressInput{
				AssociationId: address.AssociationId,
			})
			if err != nil {
				log.Printf("failed to disassociate EIP: %s, error: %v", *address.PublicIp, err)
			}
		}
		// Release the Elastic IP
		if address.AllocationId != nil {
			fmt.Printf("Releasing EIP: %v", address.PublicIp)
			fmt.Printf("Releasing EIP: %s\n", *address.PublicIp)
			_, err := client.ReleaseAddress(&ec2.ReleaseAddressInput{
				AllocationId: address.AllocationId,
			})
			if err != nil {
				log.Printf("failed to release EIP: %s, error: %v", *address.PublicIp, err)
			}
		}
	}
	if err != nil {
		return nil, err
	}

	return result, err
}

func handler(ctx context.Context, request events.APIGatewayProxyRequest) (events.APIGatewayProxyResponse, error) {
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

	runningInstances, err := GetRunningInstances(ec2Client)
	if err != nil {
		fmt.Printf("Couldn't retrieve running instances: %v", err)
	}

	for _, reservation := range runningInstances.Reservations {
		for _, instance := range reservation.Instances {
			fmt.Printf("Found running instance: %s\n", *instance.InstanceId)
			err = StopInstance(ec2Client, *instance.InstanceId)
			if err != nil {
				fmt.Printf("Couldn't stop instance: %v", err)
			}
		}
	}

	disassociateIP, _err := DisassociateAndReleaseElasticIP(ec2Client)
	if _err != nil {
		fmt.Printf("Couldn't disassociate and release Elastic IP: %v", _err)
	}

	fmt.Print(disassociateIP)

	response := events.APIGatewayProxyResponse{
		StatusCode: 200,
	}

	return response, nil
}
