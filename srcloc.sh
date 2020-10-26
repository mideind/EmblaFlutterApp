#!/bin/bash

# Print total lines of code in project

cd lib
echo "LOC Total:"
find . -name \*.dart -exec cat {} \; | wc -l
