#!/bin/bash
Region=$AWS_DEFAULT_REGION
Bucket=$KEY_PAIR_BUCKET_NAME
KeyPairName=$KEY_PAIR_NAME
key=$KeyPairName-$Region
Available_key=`aws ec2 describe-key-pairs --key-name $key | grep KeyName | awk -F\" '{print $4}'`

if [ "$key" = "$Available_key" ]; then
    echo "Key is available.."
    #Available_key=`aws ec2 describe-key-pairs --key-name $key --output`
    #aws s3 cp $key.pem s3://$Bucket/$key.pem
    aws ec2 describe-key-pairs --key-name $key --output text > $key.pem
    cat $key.pem
fi