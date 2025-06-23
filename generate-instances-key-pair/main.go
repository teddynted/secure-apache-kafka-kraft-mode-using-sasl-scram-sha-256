package main

import (
	"context"
	"log"
	"os"

	"github.com/aws/aws-lambda-go/lambda"
	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/service/ec2"

	ec2Types "github.com/aws/aws-sdk-go-v2/service/ec2/types"
	"github.com/aws/aws-sdk-go-v2/service/secretsmanager"
	secretsTypes "github.com/aws/aws-sdk-go-v2/service/secretsmanager/types"
	"github.com/aws/aws-sdk-go/aws"
)

func AwsRegion() string {

	return os.Getenv("AWS_REGION")
}

func Stage() string {

	return os.Getenv("STAGE")
}

type KeyPairResponse struct {
	KeyName    string `json:"keyName"`
	KeyPairID  string `json:"keyPairId"`
	SecretName string `json:"secretName"`
	SecretARN  string `json:"secretArn"`
	Region     string `json:"region"`
}

func generateKeyPair(ctx context.Context) (*KeyPairResponse, error) {
	// Load AWS configuration
	cfg, err := config.LoadDefaultConfig(ctx)
	if err != nil {
		log.Printf("config error: %v", err)
		return nil, err
	}
	awsRegion := AwsRegion()
	stage := Stage()
	// Generate unique key pair name
	keyName := "ec2-keypair-" + awsRegion + "-" + stage

	// Create EC2 client
	ec2Client := ec2.NewFromConfig(cfg)

	// Create key pair
	result, err := ec2Client.CreateKeyPair(ctx, &ec2.CreateKeyPairInput{
		KeyName:   aws.String(keyName),
		KeyType:   ec2Types.KeyTypeRsa,
		KeyFormat: ec2Types.KeyFormatPem,
		TagSpecifications: []ec2Types.TagSpecification{
			{
				ResourceType: ec2Types.ResourceTypeKeyPair,
				Tags: []ec2Types.Tag{
					{
						Key:   aws.String("GeneratedBy"),
						Value: aws.String("LambdaKeyGen"),
					},
				},
			},
		},
	})
	if err != nil {
		log.Printf("CreateKeyPair error: %v", err)
		return nil, err
	}

	log.Printf("Keyname: %v", keyName)

	ec2Tags := []ec2Types.Tag{
		{Key: aws.String("KeyPairName"), Value: aws.String(keyName)},
	}

	var secretsTags []secretsTypes.Tag
	for _, t := range ec2Tags {
		secretsTags = append(secretsTags, secretsTypes.Tag{
			Key:   t.Key,
			Value: t.Value,
		})
	}

	// Store private key in Secrets Manager
	smClient := secretsmanager.NewFromConfig(cfg)
	secretInput := &secretsmanager.CreateSecretInput{
		Name:         aws.String(keyName + "-private-key"),
		SecretString: result.KeyMaterial,
		Description:  aws.String("Private key for EC2 instance access"),
		Tags:         secretsTags,
	}

	secret, err := smClient.CreateSecret(ctx, secretInput)
	if err != nil {
		log.Printf("CreateSecret error: %v", err)
		return nil, err
	}

	// Return response
	response := &KeyPairResponse{
		KeyName:    keyName,
		KeyPairID:  *result.KeyPairId,
		SecretName: *secret.Name,
		SecretARN:  *secret.ARN,
		Region:     cfg.Region,
	}

	return response, nil
}

func main() {
	lambda.Start(generateKeyPair)
}
