# Deployment Guide - Mumbai vs Oregon

## For India (FAST) - Use Mumbai

**Deployment Script:**
```bash
./deploy-mumbai.sh
```

**Uses:**
- Template: `mumbai-template.yaml`
- Region: `ap-south-1` (Mumbai)
- Key: `amazon-q-key-mumbai.pem`
- S3 Script: Same as Oregon (https://s3.us-west-2.amazonaws.com/03-july-2025-qclvscodespot-4.14pm/user-data-script-s3copy.sh)

**AMI:** ami-0ade68f094cc81635 (Ubuntu 22.04 for Mumbai)

---

## For US/Global (SLOW from India) - Use Oregon

**Deployment Script:**
```bash
./deploy-uswest2a-only.sh
```

**Uses:**
- Template: `uswest2a-only-template.yaml`
- Region: `us-west-2` (Oregon)
- Key: `amazon-q-key-uswest2.pem`
- S3 Script: https://s3.us-west-2.amazonaws.com/03-july-2025-qclvscodespot-4.14pm/user-data-script-s3copy.sh

**AMI:** ami-0ec1bf4a8f92e7bd1 (Ubuntu 22.04 for Oregon)

---

## Key Differences

| Item | Mumbai | Oregon |
|------|--------|--------|
| Script | deploy-mumbai.sh | deploy-uswest2a-only.sh |
| Template | mumbai-template.yaml | uswest2a-only-template.yaml |
| Region | ap-south-1 | us-west-2 |
| AZ | ap-south-1a | us-west-2a |
| AMI | ami-0ade68f094cc81635 | ami-0ec1bf4a8f92e7bd1 |
| Key | amazon-q-key-mumbai.pem | amazon-q-key-uswest2.pem |
| S3 Script | **SAME** | **SAME** |

---

## S3 Script (Shared by Both)

**Location:** s3://03-july-2025-qclvscodespot-4.14pm/user-data-script-s3copy.sh

**Version:** Fixed with code-server 4.95.3

Both regions use the SAME S3 script. The script was updated to install code-server 4.95.3 instead of latest version.

---

## Recommendation for India

**Always use:** `./deploy-mumbai.sh`

This will be 10-20x faster for you since you're in India.
