#!/bin/bash

# Change to same directory as script
cd "$(dirname "$0")" || exit

SERVER_KEY_PATH="server.key"

SOBF=""
if [ ! -e $SERVER_KEY_PATH ]; then
    echo "File ${SERVER_KEY_PATH} not found in script directory, using empty string"
else
    SOBF=$(base64 -i ${SERVER_KEY_PATH} | tr -d '\n')
fi

cat > '../lib/keys.dart' << EOF
// This is a generated file. Do *not* check into version control.
const String serverAPIKey = '${SOBF}';
EOF
