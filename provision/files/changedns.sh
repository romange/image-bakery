#!/bin/bash

set -e

# Extract information about the Instance
INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id/)
MY_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4/)

# Extract tags associated with instance
ZONE_TAG=$(aws ssm get-parameters --names dnszone  --query "Parameters[*].{Value:Value}" --output text)
NAME_TAG=$(aws ec2 describe-tags  --output text --filters "Name=resource-id,Values=${INSTANCE_ID}" --query 'Tags[?Key==`DNS_NAME`].Value')
ZONE_NAME=$(aws route53 get-hosted-zone --id $ZONE_TAG --query "HostedZone.Name" --output text)
NAME="$NAME_TAG.${ZONE_NAME::-1}"
RS='{"Name": "'$NAME'", "Type": "A","TTL": 300,"ResourceRecords": [{"Value": "'$MY_IP'"}]}'
CB_PREFIX='{"Changes":[{"Action":"UPSERT","ResourceRecordSet":'

# Update Route 53 Record Set based on the Name tag to the current Public IP address of the Instance
aws route53 change-resource-record-sets --hosted-zone-id $ZONE_TAG \
  --change-batch "$CB_PREFIX ${RS} }]}"
