#!/bin/bash

# Get the current directory
current_dir=$(pwd)

# Find all .srt files in the current directory
srt_files=(*.srt)

# Check if there are any .srt files
if [ ${#srt_files[@]} -eq 0 ]; then
    echo "No .srt files found in $current_dir."
    exit 1
fi

# Initialize counters
modified_files=0
total_replacements=0

# Process each .srt file
for file in "${srt_files[@]}"; do
    echo ${file}

    # Count occurrences of "\n\n" before replacement
    count=$(awk 'BEGIN{RS=""; ORS="\n\n"} {print}' "$file" | grep -c '^$')

    # If there are no occurrences, skip this file
    if [ "$count" -eq 0 ]; then
        continue
    fi

    # Perform the replacement and overwrite the file
    sed ':a;N;$!ba;s/\n\n/\n/g' "$file" > temp_file && mv temp_file "$file"

    # Update counters
    ((modified_files++))
    ((total_replacements+=count))

    # Print file-specific replacement count
    echo "Modified: $file (Replaced $count occurrences of consecutive newlines)"
done

# Print summary
echo "---------------------------------"
echo "Total modified .srt files: $modified_files"
echo "Total replacements made: $total_replacements"
