#!/bin/bash

# A script to create an AWS EC2 key pair and download the private key.

# --- Configuration ---
# Replace 'my-new-key-pair' with your desired key pair name.
KEY_NAME="my-new-key-pair"

# Set the desired region for the key pair.
# Example: 'us-west-2' or 'ap-south-1'
AWS_REGION="ap-south-1"

# Set the output filename for the .pem file.
PEM_FILE="${KEY_NAME}.pem"

# --- Script Logic ---

# Check if AWS CLI is installed.
if ! command -v aws &> /dev/null
then
    echo "Error: AWS CLI is not installed. Please install it to continue."
    exit 1
fi

echo "--- Automating AWS Key Pair Creation ---"

# 1. Clean up any previous key pair with the same name in AWS.
echo "Checking for and deleting any existing key pair named '${KEY_NAME}' in region '${AWS_REGION}'..."
aws ec2 delete-key-pair --key-name "${KEY_NAME}" --region "${AWS_REGION}" > /dev/null 2>&1

# 2. Create a new key pair and save the private key material to the .pem file.
echo "Creating key pair '${KEY_NAME}' and saving private key to '${PEM_FILE}'..."
aws ec2 create-key-pair \
    --key-name "${KEY_NAME}" \
    --query 'KeyMaterial' \
    --output text \
    --region "${AWS_REGION}" > "${PEM_FILE}"

# Check if the key pair creation and download was successful.
if [ -s "${PEM_FILE}" ]; then
    echo "Successfully created key pair and downloaded private key to '${PEM_FILE}'."

    # 3. Set secure file permissions (read-only for the owner).
    echo "Setting secure permissions (chmod 400) on '${PEM_FILE}'..."
    chmod 400 "${PEM_FILE}"

    echo "--- Automation Complete ---"
    echo "The private key file '${PEM_FILE}' is ready for use."
else
    echo "Error: Key pair creation failed or private key was not saved."
    exit 1
fi


