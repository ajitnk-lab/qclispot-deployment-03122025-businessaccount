#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

STACK_NAME="amazon-q-cli-vscode-v10-enhanced-12oct2025"
REGION="us-west-2"
ELASTIC_IP="44.236.33.243"
SPOT_FLEET_ID="sfr-f7eff422-22ad-4753-9dbd-4c9174f22d19"

echo -e "${BLUE}🔍 Amazon Q CLI V10 Enhanced Deployment Monitor${NC}"
echo "=============================================="
echo "Stack: $STACK_NAME"
echo "Region: $REGION"
echo "Elastic IP: $ELASTIC_IP"
echo "Spot Fleet: $SPOT_FLEET_ID"
echo ""

while true; do
    clear
    echo -e "${BLUE}🔍 Amazon Q CLI V10 Enhanced Deployment Monitor${NC}"
    echo "=============================================="
    echo "$(date '+%Y-%m-%d %H:%M:%S UTC')"
    echo ""
    
    # Check stack status
    echo -e "${YELLOW}📋 CloudFormation Stack Status:${NC}"
    STACK_STATUS=$(aws cloudformation describe-stacks --region $REGION --stack-name $STACK_NAME --query 'Stacks[0].StackStatus' --output text 2>/dev/null)
    if [ $? -eq 0 ]; then
        echo -e "  Status: ${GREEN}$STACK_STATUS${NC}"
    else
        echo -e "  Status: ${RED}ERROR - Stack not found${NC}"
    fi
    echo ""
    
    # Check spot fleet status
    echo -e "${YELLOW}🚀 Spot Fleet Status:${NC}"
    FLEET_STATUS=$(aws ec2 describe-spot-fleet-requests --region $REGION --spot-fleet-request-ids $SPOT_FLEET_ID --query 'SpotFleetRequestConfigs[0].SpotFleetRequestState' --output text 2>/dev/null)
    FLEET_ACTIVITY=$(aws ec2 describe-spot-fleet-requests --region $REGION --spot-fleet-request-ids $SPOT_FLEET_ID --query 'SpotFleetRequestConfigs[0].ActivityStatus' --output text 2>/dev/null)
    if [ $? -eq 0 ]; then
        echo -e "  State: ${GREEN}$FLEET_STATUS${NC}"
        echo -e "  Activity: ${GREEN}$FLEET_ACTIVITY${NC}"
    else
        echo -e "  Status: ${RED}ERROR - Fleet not found${NC}"
    fi
    echo ""
    
    # Check active instances
    echo -e "${YELLOW}💻 Active Instances:${NC}"
    INSTANCES=$(aws ec2 describe-spot-fleet-instances --region $REGION --spot-fleet-request-id $SPOT_FLEET_ID --query 'ActiveInstances[*].[InstanceId,InstanceType,InstanceHealth]' --output text 2>/dev/null)
    if [ $? -eq 0 ] && [ -n "$INSTANCES" ]; then
        echo "$INSTANCES" | while read -r instance_id instance_type health; do
            echo -e "  ${GREEN}✓${NC} $instance_id ($instance_type) - $health"
            
            # Get instance details
            INSTANCE_STATE=$(aws ec2 describe-instances --region $REGION --instance-ids $instance_id --query 'Reservations[0].Instances[0].State.Name' --output text 2>/dev/null)
            AZ=$(aws ec2 describe-instances --region $REGION --instance-ids $instance_id --query 'Reservations[0].Instances[0].Placement.AvailabilityZone' --output text 2>/dev/null)
            echo -e "    State: $INSTANCE_STATE | AZ: $AZ"
        done
    else
        echo -e "  ${RED}No active instances${NC}"
    fi
    echo ""
    
    # Check VS Code Server
    echo -e "${YELLOW}🌐 VS Code Server Status:${NC}"
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 5 http://$ELASTIC_IP:8080 2>/dev/null)
    if [ "$HTTP_CODE" = "200" ]; then
        echo -e "  ${GREEN}✓ VS Code Server is running${NC} (http://$ELASTIC_IP:8080)"
    else
        echo -e "  ${RED}✗ VS Code Server not responding${NC} (HTTP: $HTTP_CODE)"
    fi
    echo ""
    
    # Check SSH connectivity
    echo -e "${YELLOW}🔑 SSH Connectivity:${NC}"
    if timeout 5 nc -z $ELASTIC_IP 22 2>/dev/null; then
        echo -e "  ${GREEN}✓ SSH port is open${NC} (ssh -i amazon-q-key-uswest2.pem ubuntu@$ELASTIC_IP)"
    else
        echo -e "  ${RED}✗ SSH port not accessible${NC}"
    fi
    echo ""
    
    # Show key information
    echo -e "${BLUE}📋 Quick Access Information:${NC}"
    echo "  VS Code Server: http://$ELASTIC_IP:8080"
    echo "  SSH Command: ssh -i amazon-q-key-uswest2.pem ubuntu@$ELASTIC_IP"
    echo "  Key File: $(pwd)/amazon-q-key-uswest2.pem"
    echo ""
    
    echo -e "${YELLOW}Press Ctrl+C to exit monitoring${NC}"
    sleep 30
done
