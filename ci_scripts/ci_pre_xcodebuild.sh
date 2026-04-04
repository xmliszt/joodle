#!/bin/bash
set -e

# Create Secrets.xcconfig from Xcode Cloud environment variables
cat > "$CI_PRIMARY_REPOSITORY_PATH/Secrets.xcconfig" <<EOF
POSTHOG_API_KEY = $POSTHOG_API_KEY
POSTHOG_HOST = $POSTHOG_HOST
EOF