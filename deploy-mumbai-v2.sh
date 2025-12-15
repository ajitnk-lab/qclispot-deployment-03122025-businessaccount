#!/bin/bash
set -e

# Amazon Q CLI V10 - MUMBAI ONLY Deployment Script
# 8 Launch Configurations in single AZ with persistent volumes
# Version: 1.0 - Single AZ with Volume Persistence

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Enhanced logging function
log() {
    local level="$1"
    shift
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    case $level in
        "INFO")  echo -e "${BLUE}[$timestamp] [INFO]${NC} $*" ;;
        "SUCCESS") echo -e "${GREEN}[$timestamp] [SUCCESS]${NC} $*" ;;
        "WARN")  echo -e "${YELLOW}[$timestamp] [WARN]${NC} $*" ;;
        "ERROR") echo -e "${RED}[$timestamp] [ERROR]${NC} $*" ;;
        "PRICE") echo -e "${PURPLE}[$timestamp] [PRICE]${NC} $*" ;;
        "CONFIG") echo -e "${CYAN}[$timestamp] [CONFIG]${NC} $*" ;;
    esac
}

# Configuration
REGION="ap-south-1"
STACK_NAME="amazon-q-cli-mumbai-v2-$(date +%d%b%Y | tr '[:upper:]' '[:lower:]')"
TEMPLATE_FILE="mumbai-template-v2.yaml"
KEY_NAME="amazon-q-key-mumbai"

# Instance families - 8 types for maximum diversity
declare -A INSTANCE_FAMILIES=(
    ["m5"]="General Purpose - Balanced compute, memory, and networking"
    ["m6i"]="Latest General Purpose - Intel 3rd gen processors"
    ["c5"]="Compute Optimized - High performance processors"
    ["c6i"]="Latest Compute Optimized - Intel 3rd gen processors"
    ["r5"]="Memory Optimized - High memory-to-vCPU ratio"
    ["r6i"]="Latest Memory Optimized - Intel 3rd gen processors"
    ["t3"]="Burstable Performance - Cost effective for variable workloads"
    ["m6a"]="AMD General Purpose - AMD EPYC processors"
)

# Default spot prices
declare -A DEFAULT_SPOT_PRICES=(
    ["m5"]="0.400"
    ["m6i"]="0.350"
    ["c5"]="0.300"
    ["c6i"]="0.280"
    ["r5"]="0.450"
    ["r6i"]="0.400"
    ["t3"]="0.200"
    ["m6a"]="0.320"
)

# Dynamic spot prices
declare -A SPOT_PRICES

# Get current spot prices for ap-south-1a
get_current_spot_prices() {
    log "PRICE" "🔍 Fetching current spot prices for ap-south-1a..."
    
    local instance_types=("m5.2xlarge" "m6i.2xlarge" "c5.2xlarge" "c6i.2xlarge" "r5.2xlarge" "r6i.2xlarge" "t3.2xlarge" "m6a.2xlarge")
    
    for instance_type in "${instance_types[@]}"; do
        local family=$(echo "$instance_type" | cut -d'.' -f1)
        
        local spot_data=$(aws ec2 describe-spot-price-history \
            --region "$REGION" \
            --instance-types "$instance_type" \
            --product-descriptions "Linux/UNIX" \
            --availability-zone "ap-south-1a" \
            --start-time "$(date -u -d '1 hour ago' '+%Y-%m-%dT%H:%M:%S')" \
            --query 'SpotPrices[0].SpotPrice' \
            --output text 2>/dev/null || echo "")
        
        if [ -n "$spot_data" ] && [ "$spot_data" != "None" ]; then
            local buffered_price=$(echo "scale=3; $spot_data * 1.25" | bc -l)
            if (( $(echo "$buffered_price > 0.500" | bc -l) )); then
                buffered_price="0.500"
            fi
            SPOT_PRICES[$family]=$buffered_price
            log "PRICE" "✅ $family: \$$spot_data -> \$$buffered_price (25% buffer)"
        else
            SPOT_PRICES[$family]=${DEFAULT_SPOT_PRICES[$family]}
            log "WARN" "$family: Using default \$${DEFAULT_SPOT_PRICES[$family]}"
        fi
    done
}

# Display configuration summary
display_summary() {
    log "CONFIG" "📊 MUMBAI ONLY DEPLOYMENT SUMMARY"
    echo "=============================================="
    echo -e "${CYAN}Region:${NC} ap-south-1"
    echo -e "${CYAN}Availability Zone:${NC} ap-south-1a only"
    echo -e "${CYAN}Instance Types (8):${NC}"
    
    for family in "${!INSTANCE_FAMILIES[@]}"; do
        echo -e "  ${GREEN}$family.2xlarge${NC}: \$${SPOT_PRICES[$family]} - ${INSTANCE_FAMILIES[$family]}"
    done
    
    echo -e "${CYAN}Features:${NC}"
    echo "  ✅ Persistent EBS volumes across spot interruptions"
    echo "  ✅ Amazon Q CLI with 17 MCP servers"
    echo "  ✅ VS Code Server (passwordless access)"
    echo "  ✅ Automatic volume attachment and mounting"
    echo "  ✅ 8 instance types for maximum availability"
    echo "=============================================="
}

# Validate prerequisites
validate_prerequisites() {
    log "INFO" "🔍 Validating prerequisites..."
    
    if [ ! -f "$TEMPLATE_FILE" ]; then
        log "ERROR" "Template not found: $TEMPLATE_FILE"
        exit 1
    fi
    
    if ! command -v aws &> /dev/null; then
        log "ERROR" "AWS CLI not found"
        exit 1
    fi
    
    if ! command -v bc &> /dev/null; then
        log "ERROR" "bc calculator not found. Install with: sudo apt-get install bc"
        exit 1
    fi
    
    if ! aws sts get-caller-identity &> /dev/null; then
        log "ERROR" "AWS credentials not configured"
        exit 1
    fi
    
    if ! aws ec2 describe-key-pairs --key-names "$KEY_NAME" --region "$REGION" &> /dev/null; then
        log "ERROR" "Key pair '$KEY_NAME' not found in $REGION"
        exit 1
    fi
    
    log "SUCCESS" "All prerequisites validated"
}

# Deploy stack
deploy_stack() {
    log "INFO" "🚀 Deploying MUMBAI ONLY stack: $STACK_NAME"
    
    local parameters=""
    parameters+="ParameterKey=KeyName,ParameterValue=$KEY_NAME "
    parameters+="ParameterKey=SpotPriceM6a,ParameterValue=${SPOT_PRICES[m6a]} "
    parameters+="ParameterKey=SpotPriceM6i,ParameterValue=${SPOT_PRICES[m6i]} "
    parameters+="ParameterKey=SpotPriceC5,ParameterValue=${SPOT_PRICES[c5]} "
    parameters+="ParameterKey=SpotPriceC6i,ParameterValue=${SPOT_PRICES[c6i]} "
    parameters+="ParameterKey=SpotPriceR5,ParameterValue=${SPOT_PRICES[r5]} "
    parameters+="ParameterKey=SpotPriceR6i,ParameterValue=${SPOT_PRICES[r6i]} "
    parameters+="ParameterKey=SpotPriceT3,ParameterValue=${SPOT_PRICES[t3]}"
    
    aws cloudformation create-stack \
        --stack-name "$STACK_NAME" \
        --template-body "file://$TEMPLATE_FILE" \
        --parameters $parameters \
        --capabilities CAPABILITY_IAM \
        --region "$REGION" \
        --tags Key=Project,Value=qspotcli Key=Version,Value=V1 Key=Environment,Value=Prod Key=Purpose,Value=qdevelperproonspot
    
    log "SUCCESS" "Stack deployment initiated"
}

# Monitor deployment
monitor_deployment() {
    log "INFO" "📊 Monitoring deployment progress..."
    
    while true; do
        local status=$(aws cloudformation describe-stacks \
            --stack-name "$STACK_NAME" \
            --region "$REGION" \
            --query 'Stacks[0].StackStatus' \
            --output text 2>/dev/null || echo "UNKNOWN")
        
        case $status in
            "CREATE_COMPLETE")
                log "SUCCESS" "🎉 Deployment completed successfully!"
                break
                ;;
            "CREATE_FAILED"|"ROLLBACK_COMPLETE")
                log "ERROR" "Deployment failed: $status"
                exit 1
                ;;
            "CREATE_IN_PROGRESS")
                log "INFO" "Deployment in progress..."
                ;;
        esac
        
        sleep 30
    done
}

# Get deployment outputs
get_outputs() {
    log "INFO" "📋 Getting deployment information..."
    
    local outputs=$(aws cloudformation describe-stacks \
        --stack-name "$STACK_NAME" \
        --region "$REGION" \
        --query 'Stacks[0].Outputs')
    
    if [ "$outputs" != "null" ]; then
        echo
        log "SUCCESS" "🎉 MUMBAI DEPLOYMENT COMPLETE!"
        echo "=============================================="
        
        local elastic_ip=$(echo "$outputs" | jq -r '.[] | select(.OutputKey=="ElasticIP") | .OutputValue')
        local vscode_url=$(echo "$outputs" | jq -r '.[] | select(.OutputKey=="VSCodeServerURL") | .OutputValue')
        local ssh_command=$(echo "$outputs" | jq -r '.[] | select(.OutputKey=="SSHCommand") | .OutputValue')
        
        echo -e "${GREEN}🌐 Elastic IP:${NC} $elastic_ip"
        echo -e "${GREEN}💻 VS Code Server:${NC} $vscode_url"
        echo -e "${GREEN}🔑 SSH Command:${NC} $ssh_command"
        echo -e "${GREEN}📍 Location:${NC} ap-south-1a only"
        echo -e "${GREEN}💾 Persistent Storage:${NC} Automatic EBS volume attachment"
        echo "=============================================="
    fi
}

# Main function
main() {
    echo "=============================================="
    echo "🚀 Amazon Q CLI - MUMBAI ONLY Deployment"
    echo "   8 Instance Types | Persistent Volumes"
    echo "=============================================="
    echo
    
    validate_prerequisites
    get_current_spot_prices
    display_summary
    
    echo
    log "INFO" "Auto-proceeding with deployment..."
    
    deploy_stack
    monitor_deployment
    get_outputs
    
    log "SUCCESS" "🎉 MUMBAI deployment completed!"
}

# Run main function
main
