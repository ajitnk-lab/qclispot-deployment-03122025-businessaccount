#!/usr/bin/env python3
import re

# Read the template
with open('mumbai-template-v2.yaml', 'r') as f:
    content = f.content()

# The old problematic curl line
old_pattern = r'curl --retry 5 --retry-delay 3 --retry-max-time 60 --connect-timeout 10 -o /tmp/user-data-script-s3copy\.sh "https://s3\.us-west-2\.amazonaws\.com/03-july-2025-qclvscodespot-4\.14pm/user-data-script-s3copy-v2\.sh"'

# New robust download logic
new_code = '''# Wait for network stability
                sleep 5
                
                # Robust download with curl and wget fallback
                DOWNLOADED=false
                for attempt in 1 2 3; do
                  log "Download attempt $attempt..."
                  if curl -f --max-time 30 -o /tmp/user-data-script-s3copy.sh "https://s3.us-west-2.amazonaws.com/03-july-2025-qclvscodespot-4.14pm/user-data-script-s3copy-v2.sh" 2>>/var/log/amazon-q-setup.log; then
                    DOWNLOADED=true
                    break
                  fi
                  if wget --timeout=30 -O /tmp/user-data-script-s3copy.sh "https://s3.us-west-2.amazonaws.com/03-july-2025-qclvscodespot-4.14pm/user-data-script-s3copy-v2.sh" 2>>/var/log/amazon-q-setup.log; then
                    DOWNLOADED=true
                    break
                  fi
                  sleep 3
                done
                
                if [ "$DOWNLOADED" != "true" ]; then
                  log "❌ Failed to download setup script after 3 attempts"
                  exit 1
                fi
                log "✅ Download successful"'''

# Replace
content = re.sub(old_pattern, new_code, content)

# Write back
with open('mumbai-template-v2-fixed.yaml', 'w') as f:
    f.write(content)

print("Fixed template created: mumbai-template-v2-fixed.yaml")
