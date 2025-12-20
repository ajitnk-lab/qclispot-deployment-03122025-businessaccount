#!/bin/bash

# Backup original
cp mumbai-template-v2.yaml mumbai-template-v2.yaml.backup

# Replace the problematic curl command with robust download logic
sed -i 's|curl --retry 5 --retry-delay 3 --retry-max-time 60 --connect-timeout 10 -o /tmp/user-data-script-s3copy.sh "https://s3.us-west-2.amazonaws.com/03-july-2025-qclvscodespot-4.14pm/user-data-script-s3copy-v2.sh"|sleep 5\n                for attempt in {1..3}; do\n                  if curl --retry 2 --max-time 30 -f -o /tmp/user-data-script-s3copy.sh "https://s3.us-west-2.amazonaws.com/03-july-2025-qclvscodespot-4.14pm/user-data-script-s3copy-v2.sh" 2>>/var/log/amazon-q-setup.log \\|\\| wget --tries=2 --timeout=30 -O /tmp/user-data-script-s3copy.sh "https://s3.us-west-2.amazonaws.com/03-july-2025-qclvscodespot-4.14pm/user-data-script-s3copy-v2.sh" 2>>/var/log/amazon-q-setup.log; then\n                    log "✅ Download successful on attempt $attempt"\n                    break\n                  fi\n                  log "Download attempt $attempt failed, retrying..."\n                  sleep 3\n                done\n                if [ ! -f /tmp/user-data-script-s3copy.sh ]; then\n                  log "❌ Failed to download setup script"\n                  exit 1\n                fi|g' mumbai-template-v2.yaml

echo "Template fixed!"
