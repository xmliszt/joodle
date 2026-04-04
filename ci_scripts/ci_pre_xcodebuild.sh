#!/bin/bash
set -e

# Create Secrets.xcconfig from Xcode Cloud environment variables
cat > "$CI_PRIMARY_REPOSITORY_PATH/Secrets.xcconfig" <<EOF
API_KEY = $API_KEY
API_SECRET = $API_SECRET
// add whatever keys your xcconfig expects
EOF