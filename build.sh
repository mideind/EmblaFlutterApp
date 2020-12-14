#!/bin/bash

/bin/bash gen_keysfile.sh

# Build APK for Android
flutter build apk --release --obfuscate --split-debug-info=/tmp/
