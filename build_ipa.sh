#!/bin/bash
# Build IPA for iOS
# Part of CI process

/bin/bash keys/gen_keys.sh

# flutter build ios \
# --obfuscate \
# --split-debug-info=/tmp/ \
# --no-tree-shake-icons \
# --suppress-analytics \
# --release \

cd ios/ || exit 1

pod install || exit 1

xcodebuild  -parallelizeTargets \
            -workspace "Runner.xcworkspace" \
            -scheme "Runner" \
            -configuration "Release" \
            CODE_SIGN_IDENTITY="" \
            CODE_SIGNING_ALLOWED=NO \
            CODE_SIGNING_REQUIRED=NO \
            clean build \
            | xcpretty -c && exit ${PIPESTATUS[0]}