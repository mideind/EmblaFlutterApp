#!/bin/bash

# Change to same directory as script
cd "$(dirname "$0")" || exit

QUERY_KEY_PATH="query_api.key"

QOBF=""
if [ ! -e $QUERY_KEY_PATH ]; then
    echo "File ${QUERY_KEY_PATH} not found in script directory, using empty string"
else
    QOBF=$(base64 -i ${QUERY_KEY_PATH} | tr -d '\n')
fi

cat > '../lib/keys.dart' << EOF
// This is a generated file. Do *not* check into version control.
const String queryAPIKey = '${QOBF}';
EOF
