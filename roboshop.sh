#!/bin/bash
set -euo pipefail

SG_ID="sg-005f466126c3865b6"
AMI_ID="ami-0220d79f3f480ecf5"
ZONE_ID="Z00087883QCEFVVFLOJWL"
DOMAIN_NAME="vakiti.online"

for instance in "$@"
do
  INSTANCE_ID=$(aws ec2 run-instances \
    --image-id "$AMI_ID" \
    --instance-type t3.micro \
    --security-group-ids "$SG_ID" \
    --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=$instance}]" \
    --query 'Instances[0].InstanceId' \
    --output text
  )

  if [[ "$instance" == "frontend" ]]; then
    IP=$(aws ec2 describe-instances \
      --instance-ids "$INSTANCE_ID" \
      --query 'Reservations[].Instances[].PublicIpAddress' \
      --output text
    )
  else
    IP=$(aws ec2 describe-instances \
      --instance-ids "$INSTANCE_ID" \
      --query 'Reservations[].Instances[].PrivateIpAddress' \
      --output text
    )
  fi

  echo "IP Address: $IP"

  aws route53 change-resource-record-sets \
    --hosted-zone-id "$ZONE_ID" \
    --change-batch "{
      \"Comment\": \"Creating a record via shell script\",
      \"Changes\": [{
        \"Action\": \"UPSERT\",
        \"ResourceRecordSet\": {
          \"Name\": \"$instance.$DOMAIN_NAME\",
          \"Type\": \"A\",
          \"TTL\": 60,
          \"ResourceRecords\": [{ \"Value\": \"$IP\" }]
        }
      }]
    }"

  echo "record updated for $instance"
done
