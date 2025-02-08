#!/bin/bash

# Determine the target directory
if [ $# -eq 0 ]; then
    target_dir="."
elif [ $# -eq 1 ]; then
    if [ -d "$1" ]; then
        target_dir="$1"
    else
        echo "Error: Directory '$1' does not exist."
        exit 1
    fi
else
    echo "Usage: $0 [directory]"
    exit 1
fi

# Change to the target directory
cd "$target_dir" || exit 1

# Initialize success counter
success_count=0

# Loop through all .mkv files in the target directory
for mkv_file in *.mkv; do
    # Skip if no .mkv file is found
    [ -e "$mkv_file" ] || continue
    
    # Generate the corresponding .mp4 filename
    mp4_file="${mkv_file%.mkv}.mp4"

    # Check if the .mp4 file already exists
    if [ -f "$mp4_file" ]; then
        echo "File already exists, skipping: $mp4_file"
    else
        # Run ffmpeg while suppressing output
        if ffmpeg -i "$mkv_file" -c:v copy -c:a copy "$mp4_file" -y > /dev/null 2>&1; then
            echo "Conversion successful: $mkv_file -> $mp4_file"
            ((success_count++))
        else
            echo "Error converting: $mkv_file"
        fi
    fi
done

# Print total success count
echo "Total files converted successfully: $success_count"
