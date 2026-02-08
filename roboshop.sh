#!/bin/bash

echo "*********Running roboshop sh*************"

AMI_ID="ami-0220d79f3f480ecf5"
SG_ID="sg-005f466126c3865b6"
DOMAIN_NAME="vakiti.online"
ZONE_ID="Z00087883QCEFVVFLOJWL"


for instance in $@
do 
    # ===== CREATE INSTANCE =====
    INSTANCE_ID=$(aws ec2 run-instances \
    --image-id "$AMI_ID" \
    --instance-type "t3.micro" \
    --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=$instance}]" \
    --security-group-ids "$SG_ID" \
    --query 'Instances[0].InstanceId' \
    --output text)

    if [ $? -ne 0 ]; then
        echo "Failed to launch instance $instance."
        exit 1  
    fi

    echo "$instance created: $INSTANCE_ID"

    # ===== WAIT UNTIL RUNNING =====
    aws ec2 wait instance-running \
    --instance-ids "$INSTANCE_ID" \
    --region "us-east-1"
    echo "Instance of $instance is running.."

    # ===== GET PUBLIC IP =====
    if [ $instance == "frontend" ]; then 
        IP=$(aws ec2 describe-instances \
        --instance-ids "$INSTANCE_ID" \
        --query 'Reservations[0].Instances[0].PublicIpAddress' \
        --output text)

        RECORD_NAME="$DOMAIN_NAME"
    else
        IP=$(aws ec2 describe-instances \
        --instance-ids "$INSTANCE_ID" \
        --query 'Reservations[0].Instances[0].PrivateIpAddress' \
        --output text)     
        RECORD_NAME="$instance.$DOMAIN_NAME"
    fi   

    echo "Instance for $instance is up and running on IP: $IP"


        # ===== CREATE / UPDATE ROUTE53 RECORD =====
    aws route53 change-resource-record-sets \
        --hosted-zone-id "$ZONE_ID" \
        --change-batch "{
            \"Changes\": [{
                \"Action\": \"UPSERT\",
                \"ResourceRecordSet\": {
                    \"Name\": \"$RECORD_NAME\",
                    \"Type\": \"A\",
                    \"TTL\": 1,
                    \"ResourceRecords\": [{\"Value\": \"$IP\"}]
                }
            }]
        }"

    echo "DNS record created: ${instance}.${DOMAIN_NAME} → $IP"

done