#!/bin/bash

# Change to same directory as script
cd "$(dirname "$0")" || exit

GOOGLE_ACCOUNT_PATH="gaccount.json"
QUERY_KEY_PATH="query_api.key"

GOBF=""
if [ ! -e $GOOGLE_ACCOUNT_PATH ]; then
    echo "File ${GOOGLE_ACCOUNT_PATH} not found in script directory, using empty string"
else
    GOBF=$(base64 -i ${GOOGLE_ACCOUNT_PATH} | tr -d '\n')
fi

QOBF=""
if [ ! -e $QUERY_KEY_PATH ]; then
    echo "File ${QUERY_KEY_PATH} not found in script directory, using empty string"
else
    QOBF=$(base64 -i ${QUERY_KEY_PATH} | tr -d '\n')
fi

cat > '../lib/keys.dart' << EOF
const String googleServiceAccount = '${GOBF}';
const String queryAPIKey = '${QOBF}';
EOF

