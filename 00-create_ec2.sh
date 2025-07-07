#!/bin/bash


NAMES=$@
IMAGE_ID="ami-0f918f7e67a3323f0"
SECURITY_GROUP_ID="sg-0c0190c3602b07f27"
KEY_NAME="EC2-key"
INSTANCE_TYPE="t2.micro"

for i in $@
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


# To install the AWS CLI, run the following commands --> 

# curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
# unzip awscliv2.zip
# sudo ./aws/install

# Run the configure command-->
                # aws configure
# The command will prompt you for four pieces of information. Here's what to enter:
# AWS Access Key ID: [PASTE YOUR ACCESS KEY ID HERE]
# AWS Secret Access Key: [PASTE YOUR SECRET ACCESS KEY HERE]
# Default region name: Enter the region where you want to create your instances (e.g., us-east-1, eu-west-2). This must match the region where your IMAGE_ID, SECURITY_GROUP_ID, and KEY_NAME exist.
# Default output format: Type json and press Enter. The script relies on this format.

# jq Utility: Install -->

#     sudo yum install -y jq 
#     sudo apt-get update && sudo apt-get install -y jq
