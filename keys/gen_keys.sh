#!/bin/bash

# Generates lib/keys.dart from the (optional) key files in this directory.
# Each key file should contain a single API key. Missing files result in an
# empty string for the corresponding Dart constant.

# Change to same directory as script
cd "$(dirname "$0")" || exit

# Dart constant name : key file name
KEYS=(
    "serverAPIKey:server.key"
    "openAIAPIKey:openai.key"
    "elevenLabsAPIKey:elevenlabs.key"
    "anthropicAPIKey:anthropic.key"
)

OUTFILE="../lib/keys.dart"

echo "// This is a generated file. Do *not* check into version control." > "${OUTFILE}"

for ENTRY in "${KEYS[@]}"; do
    NAME="${ENTRY%%:*}"
    KEY_PATH="${ENTRY##*:}"
    OBF=""
    if [ ! -e "${KEY_PATH}" ]; then
        echo "File ${KEY_PATH} not found in script directory, using empty string"
    else
        OBF=$(base64 -i "${KEY_PATH}" | tr -d '\n')
    fi
    echo "const String ${NAME} = '${OBF}';" >> "${OUTFILE}"
done
