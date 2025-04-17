Region=$AWS_DEFAULT_REGION
Bucket=$KEY_PAIR_BUCKET_NAME
KeyPairName=$KEY_PAIR_NAME
key=$KeyPairName-$Region
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
    --region $Region \
    --output text > $key.pem
    if aws s3 ls "s3://$Bucket" 2>/dev/null; then
        echo "Bucket exists"
        # Upload to s3
        aws s3 cp $key.pem s3://$Bucket/$key.pem
    else
        echo "Bucket does not exist or you lack permissions"
    fi
fi