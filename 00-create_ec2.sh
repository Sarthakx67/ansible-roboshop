#!/bin/bash


NAMES=("mongodb")
IMAGE_ID="ami-0f918f7e67a3323f0"
SECURITY_GROUP_ID="sg-0c0190c3602b07f27"
KEY_NAME="EC2-key"
INSTANCE_TYPE="t2.micro"

for i in "${NAMES[@]}"
do
    echo "--------------------------------------------"
    echo "Processing Instance: $i"

    EXISTING_IP=$(aws ec2 describe-instances --filters "Name=tag:Name,Values=$i" "Name=instance-state-name,Values=pending,running" --query 'Reservations[*].Instances[*].PrivateIpAddress' --output text)

    if [ -n "$EXISTING_IP" ]; then
        echo "Instance '$i' already exists. IP Address: $EXISTING_IP"
    else

        echo "Instance '$i' not found. Creating a new one..."
        
        echo "Instance type will be: $INSTANCE_TYPE"

        IP_ADDRESS=$(aws ec2 run-instances \
            --image-id "$IMAGE_ID" \
            --instance-type "$INSTANCE_TYPE" \
            --security-group-ids "$SECURITY_GROUP_ID" \
            --key-name "$KEY_NAME" \
            --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=$i}]" \
            | jq -r '.Instances[0].PrivateIpAddress')

        if [ -n "$IP_ADDRESS" ]; then
            echo "SUCCESS: Created '$i' instance. Private IP: $IP_ADDRESS"
        else
            echo "ERROR: Failed to create '$i' instance."
        fi
    fi
done

echo "--------------------------------------------"
echo "Script finished."