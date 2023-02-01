#!/bin/bash
# Build IPA for iOS
# Part of CI build process

/bin/bash keys/gen_keys.sh

# flutter build ios \
# --obfuscate \
# --split-debug-info=/tmp/ \
# --no-tree-shake-icons \
# --suppress-analytics \
# --release \

cd ios/ || exit 1

pod install || exit 1

# Build app workspace directly via Xcode to get
# around flutter insisting on signing the app.
# The output is filtered through xcpretty to
# make it shorter and more readable.
xcodebuild  -parallelizeTargets \
            -workspace "Runner.xcworkspace" \
            -scheme "Runner" \
            -configuration "Release" \
            CODE_SIGN_IDENTITY="" \
            CODE_SIGNING_ALLOWED=NO \
            CODE_SIGNING_REQUIRED=NO \
            clean build \
            | xcpretty -c && exit ${PIPESTATUS[0]}