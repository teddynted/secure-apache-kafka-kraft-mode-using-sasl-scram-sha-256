#!/bin/bash
Region=$AWS_DEFAULT_REGION
Bucket=$KEY_PAIR_BUCKET_NAME
KeyPairName=$KEY_PAIR_NAME
key=$KeyPairName-$Region
Available_key=`aws ec2 describe-key-pairs --key-name $key | grep KeyName | awk -F\" '{print $4}'`

if [ "$key" = "$Available_key" ]; then
    echo "Key is available.."
else
    echo "Key is not available: Creating new key"
    aws ec2 create-key-pair \
    --key-name $key \
    --key-type rsa \
    --key-format pem \
    --query "KeyMaterial" \
    --region $Region \
    --output text > $key.pem
    aws s3 cp $key.pem s3://$Bucket/$key.pem
fi

template_id=$(aws ec2 describe-launch-templates --query "LaunchTemplates[0].LaunchTemplateId" --output text)
response=$(aws ec2 describe-launch-template-versions --launch-template-id $template_id --query "LaunchTemplateVersions[0].VersionNumber")
aws ec2 modify-launch-template --launch-template-id $template_id --default-version $response --region $Region