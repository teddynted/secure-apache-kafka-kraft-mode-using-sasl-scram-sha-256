#!/bin/bash
REGION=$AWS_DEFAULT_REGION
BUCKET_NAME=$KEY_PAIR_BUCKET_NAME
KeyPairName=$KEY_PAIR_NAME
key=$KeyPairName-$REGION
Available_key=`aws ec2 describe-key-pairs --key-name $key | grep KeyName | awk -F\" '{print $4}'`

if [ "$key" = "$Available_key" ]; then
    echo "Key is available."
else
    echo "Key is not available, Creating a new key"
    # Create a new key pair
    aws ec2 create-key-pair \
    --key-name $key \
    --key-type rsa \
    --key-format pem \
    --query "KeyMaterial" \
    --region $REGION \
    --output text > $key.pem
fi