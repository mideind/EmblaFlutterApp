#!/bin/bash
# Build Arm64 APK for Android
# Part of CI process

/bin/bash keys/gen_keys.sh

flutter build apk \
--obfuscate \
--split-debug-info=/tmp/ \
--target-platform=android-arm64 \
# --release \
# --split-per-abi
