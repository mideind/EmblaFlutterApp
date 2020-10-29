#!/bin/sh
# Copies Embla HTML documentation to server
# Invoke with ./deploy.sh user@greynir.is

if [ -z "$1" ]; then
    echo "No argument supplied"
    exit
fi

DEST="$1:/usr/share/nginx/embla.is/static/"

# Copy files to server
scp *.html *.woff2 *.css $DEST
