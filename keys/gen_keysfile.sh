#!/bin/bash

# Change to same directory as script
cd "$(dirname "$0")"

GOOGLE_ACCOUNT_PATH="gaccount.json"
GREYNIR_KEY_PATH="GreynirAPI.key"

if [ ! -e $GOOGLE_ACCOUNT_PATH ]; then
    echo "File ${GOOGLE_ACCOUNT_PATH} not found in script directory"
    exit 1
fi

if [ ! -e $GREYNIR_KEY_PATH ]; then
    echo "File ${GREYNIR_KEY_PATH} not found in script directory"
    exit 1
fi

GOBF=`base64 -i ${GOOGLE_ACCOUNT_PATH}`
SOBF=`base64 -i ${GREYNIR_KEY_PATH}`

cat > '../lib/keys.dart' << EOF
const String googleServiceAccount = "${GOBF}";

const String queryAPIKey = "${SOBF}";

EOF

