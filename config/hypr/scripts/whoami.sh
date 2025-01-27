#!/usr/bin/env bash

# Get the current username
USERNAME=$(whoami)

# Try to extract the full name from the /etc/passwd file
FULL_NAME=$(getent passwd "$USERNAME" | cut -d ':' -f 5 | cut -d ',' -f 1)

# Extract the first name from the full name
FIRST_NAME=$(echo "$FULL_NAME" | awk '{print $1}')

# Fallback if no full name is available
if [ -z "$FIRST_NAME" ]; then
   echo "Hello, $USERNAME" 
else
    echo "Hello, $FIRST_NAME"
fi

