#!/bin/bash

/bin/bash keys/gen_keys.sh

# Build APK for Android
flutter build apk --release --obfuscate --split-debug-info=/tmp/ 
# --split-per-abi
