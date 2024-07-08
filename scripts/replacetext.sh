#!/usr/bin/env bash

# Function to recursively replace strings in files
replace_strings() {
    local search_str="$1"
    local replace_str="$2"
    local directory="$3"

    # Loop through all files in the directory recursively
    find "$directory" -type f -print0 | while IFS= read -r -d '' file; do
        # Perform the string replacement using sed with a different delimiter
        sed -i "s|$search_str|$replace_str|g" "$file"
        echo "Replaced '$search_str' with '$replace_str' in file: $file"
    done

    echo "String replacement process completed."
}

# Check if the correct number of arguments are provided
if [ "$#" -ne 3 ]; then
    echo "Usage: $0 <search_string> <replace_string> <directory>"
    exit 1
fi

# Call the replace_strings function with provided arguments
replace_strings "$1" "$2" "$3"
