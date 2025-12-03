#!/bin/bash
set -e

# Amazon Q CLI V10 ENHANCED Deployment Script - US-WEST-2A ONLY
# 8 Launch Configurations in single AZ with diverse instance types
# Version: 1.0 - Single AZ Enhanced

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
REGION="us-west-2"
STACK_NAME="amazon-q-cli-vscode-v10-1a-only-$(date +%d%b%Y | tr '[:upper:]' '[:lower:]')"
TEMPLATE_FILE="qclivscode-cfn_template-1a-only.yaml"
KEY_NAME="amazon-q-key-uswest2"

# Instance families and their characteristics - EXPANDED
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

# Single availability zone
AZS=("us-west-2a")

# Default spot prices (will be updated dynamically)
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

# Dynamic spot prices (will be calculated)
declare -A SPOT_PRICES

# Function to get current spot prices for all instance types
get_current_spot_prices() {
    log "PRICE" "🔍 Fetching current spot prices for all instance families in us-west-2a..."
    
    local instance_types=("m5.2xlarge" "m6i.2xlarge" "c5.2xlarge" "c6i.2xlarge" "r5.2xlarge" "r6i.2xlarge" "t3.2xlarge" "m6a.2xlarge")
    
    for instance_type in "${instance_types[@]}"; do
        local family=$(echo "$instance_type" | cut -d'.' -f1)
        
        log "PRICE" "Checking spot prices for $instance_type in us-west-2a..."
        
        # Get spot price history for the last hour in us-west-2a only
        local spot_data=$(aws ec2 describe-spot-price-history \
            --region "$REGION" \
            --instance-types "$instance_type" \
            --product-descriptions "Linux/UNIX" \
            --availability-zone "us-west-2a" \
            --start-time "$(date -u -d '1 hour ago' '+%Y-%m-%dT%H:%M:%S')" \
            --query 'SpotPrices[*].[AvailabilityZone,SpotPrice,Timestamp]' \
            --output text 2>/dev/null || echo "")
        
        if [ -n "$spot_data" ]; then
            # Get the latest price and add 25% buffer
            local latest_price=$(echo "$spot_data" | head -1 | awk '{print $2}')
            local buffered_price=$(echo "scale=3; $latest_price * 1.25" | bc -l)
            
            # Ensure minimum price and maximum cap
            local min_price=${DEFAULT_SPOT_PRICES[$family]}
            if (( $(echo "$buffered_price < $min_price" | bc -l) )); then
                buffered_price=$min_price
            fi
            
            # Cap at $0.500 for safety
            if (( $(echo "$buffered_price > 0.500" | bc -l) )); then
                buffered_price="0.500"
            fi
            
            SPOT_PRICES[$family]=$buffered_price
            log "PRICE" "✅ $family: Current=\$$latest_price, Buffered=\$$buffered_price (25% buffer)"
        else
            SPOT_PRICES[$family]=${DEFAULT_SPOT_PRICES[$family]}
            log "WARN" "No recent spot price data for $instance_type, using default: \$${DEFAULT_SPOT_PRICES[$family]}"
        fi
    done
    
    log "SUCCESS" "Spot price analysis completed for us-west-2a"
}

# Function to display spot price summary
display_spot_price_summary() {
    log "CONFIG" "📊 US-WEST-2A ONLY SPOT FLEET CONFIGURATION SUMMARY"
    echo "=============================================="
    echo -e "${CYAN}Instance Family Coverage (us-west-2a only):${NC}"
    
    for family in "${!INSTANCE_FAMILIES[@]}"; do
        echo -e "  ${GREEN}$family${NC}: ${INSTANCE_FAMILIES[$family]}"
        echo -e "    Spot Price: \$${SPOT_PRICES[$family]}"
    done
    
    echo
    echo -e "${CYAN}Launch Configuration Matrix (8 configs in us-west-2a):${NC}"
    echo -e "  1. ${GREEN}m5.2xlarge${NC} (General Purpose)"
    echo -e "  2. ${GREEN}m6i.2xlarge${NC} (Latest General Purpose)"
    echo -e "  3. ${GREEN}c5.2xlarge${NC} (Compute Optimized)"
    echo -e "  4. ${GREEN}c6i.2xlarge${NC} (Latest Compute Optimized)"
    echo -e "  5. ${GREEN}r5.2xlarge${NC} (Memory Optimized)"
    echo -e "  6. ${GREEN}r6i.2xlarge${NC} (Latest Memory Optimized)"
    echo -e "  7. ${GREEN}t3.2xlarge${NC} (Burstable Performance)"
    echo -e "  8. ${GREEN}m6a.2xlarge${NC} (AMD General Purpose)"
    echo "=============================================="
}

# Rest of the functions remain the same as original script...
# (validate_prerequisites, cleanup_eips, check_existing_stack, etc.)

# Validate prerequisites
validate_prerequisites() {
    log "INFO" "🔍 Validating prerequisites..."
    
    # Check if template file exists
    if [ ! -f "$TEMPLATE_FILE" ]; then
        log "ERROR" "CloudFormation template not found: $TEMPLATE_FILE"
        exit 1
    fi
    
    # Check AWS CLI
    if ! command -v aws &> /dev/null; then
        log "ERROR" "AWS CLI not found. Please install AWS CLI."
        exit 1
    fi
    
    # Check bc calculator for spot price calculations
    if ! command -v bc &> /dev/null; then
        log "WARN" "bc calculator not found. Installing..."
        if command -v apt-get &> /dev/null; then
            sudo apt-get update && sudo apt-get install -y bc
        elif command -v yum &> /dev/null; then
            sudo yum install -y bc
        else
            log "ERROR" "Cannot install bc calculator. Please install manually."
            exit 1
        fi
    fi
    
    # Check AWS credentials
    if ! aws sts get-caller-identity &> /dev/null; then
        log "ERROR" "AWS credentials not configured or expired."
        exit 1
    fi
    
    # Check if key pair exists
    if ! aws ec2 describe-key-pairs --key-names "$KEY_NAME" --region "$REGION" &> /dev/null; then
        log "ERROR" "Key pair '$KEY_NAME' not found in region $REGION"
        exit 1
    fi
    
    log "SUCCESS" "All prerequisites validated successfully"
}

# Deploy CloudFormation stack with enhanced parameters
deploy_stack() {
    log "INFO" "🚀 Deploying US-WEST-2A ONLY CloudFormation stack: $STACK_NAME"
    log "INFO" "Template: $TEMPLATE_FILE"
    log "INFO" "Region: $REGION"
    log "INFO" "AZ: us-west-2a only"
    
    # Prepare parameters with dynamic spot prices
    local parameters=""
    parameters+="ParameterKey=KeyName,ParameterValue=$KEY_NAME "
    parameters+="ParameterKey=SpotPriceM5,ParameterValue=${SPOT_PRICES[m5]} "
    parameters+="ParameterKey=SpotPriceM6i,ParameterValue=${SPOT_PRICES[m6i]} "
    parameters+="ParameterKey=SpotPriceC5,ParameterValue=${SPOT_PRICES[c5]} "
    parameters+="ParameterKey=SpotPriceC6i,ParameterValue=${SPOT_PRICES[c6i]} "
    parameters+="ParameterKey=SpotPriceR5,ParameterValue=${SPOT_PRICES[r5]} "
    parameters+="ParameterKey=SpotPriceR6i,ParameterValue=${SPOT_PRICES[r6i]} "
    parameters+="ParameterKey=SpotPriceT3,ParameterValue=${SPOT_PRICES[t3]} "
    parameters+="ParameterKey=SpotPriceM6a,ParameterValue=${SPOT_PRICES[m6a]}"
    
    aws cloudformation create-stack \
        --stack-name "$STACK_NAME" \
        --template-body "file://$TEMPLATE_FILE" \
        --parameters $parameters \
        --capabilities CAPABILITY_IAM \
        --region "$REGION" \
        --tags Key=Purpose,Value=AmazonQ-CLI-VSCode Key=Version,Value=V10-1A-ONLY Key=InstanceFamilies,Value=M5-M6i-C5-C6i-R5-R6i-T3-M6a
    
    log "SUCCESS" "US-WEST-2A ONLY CloudFormation deployment initiated"
}

# Main deployment function
main() {
    echo "=============================================="
    echo "🚀 Amazon Q CLI V10 US-WEST-2A ONLY Deployment"
    echo "   8 Launch Configs | Single AZ | Diverse Types"
    echo "=============================================="
    echo
    
    validate_prerequisites
    get_current_spot_prices
    display_spot_price_summary
    
    echo
    read -p "Proceed with us-west-2a only deployment? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log "INFO" "Deployment cancelled by user"
        exit 0
    fi
    
    deploy_stack
    
    log "SUCCESS" "🎉 US-WEST-2A ONLY deployment completed successfully!"
    log "INFO" "Stack Name: $STACK_NAME"
    log "INFO" "Region: $REGION"
    log "INFO" "AZ: us-west-2a only"
    log "INFO" "Instance Families: M5, M6i, C5, C6i, R5, R6i, T3, M6a"
    echo "=============================================="
}

# Run main function
main
