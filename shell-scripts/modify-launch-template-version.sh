#!/bin/bash
Region=$AWS_DEFAULT_REGION

template_id=$(aws ec2 describe-launch-templates --query "LaunchTemplates[0].LaunchTemplateId" --output text)
response=$(aws ec2 describe-launch-template-versions --launch-template-id $template_id --query "LaunchTemplateVersions[0].VersionNumber")
aws ec2 modify-launch-template --launch-template-id $template_id --default-version $response --region $Region