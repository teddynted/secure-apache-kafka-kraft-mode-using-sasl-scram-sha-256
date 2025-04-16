#!/bin/bash
Region=$AWS_DEFAULT_REGION
Bucket=$KEY_PAIR_BUCKET_NAME
KeyPairName=$KEY_PAIR_NAME
key=$KeyPairName-$Region
Available_key=`aws ec2 describe-key-pairs --key-name $key | grep KeyName | awk -F\" '{print $4}'`

if [ "$key" = "$Available_key" ]; then
    echo "Key is available."
else
    echo "Key is not available, Creating a new key"
    # Create a new key pai
    aws ec2 create-key-pair \
    --key-name $key \
    --key-type rsa \
    --key-format pem \
    --query "KeyMaterial" \
    --region $Region \
    --output text > $key.pem
    # Create an s3 bucket and upload the key pair to s3
    aws s3api create-bucket \
        --acl private \
        --bucket $Bucket \
        --region $Region
    # Upload to s3
    aws s3 cp $key.pem s3://$Bucket/$key.pem
fi