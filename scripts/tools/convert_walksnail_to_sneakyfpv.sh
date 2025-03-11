#!/bin/bash

# Check if the directory path is provided as an argument
if [ $# -lt 1 ]; then
    echo "Usage: $0 <directory_path>"
    exit 1
fi

# The directory containing PNG files (input directory)
INPUT_DIR="$1"

# Check if the directory exists
if [ ! -d "$INPUT_DIR" ]; then
    echo "Directory not found: $INPUT_DIR"
    exit 1
fi

# Current directory where output files will be saved
OUTPUT_DIR="$(pwd)"

# Array to hold the names of converted files
converted_files=()

# Find all PNG files in the input directory and process each one
find "$INPUT_DIR" -type f -iname "*.png" | while read file; do
    # Extract the base name of the file (without path and extension)
    filename=$(basename "$file" .png)
    
    # Create the output file name by appending _SneakyFPV
    output_file="${OUTPUT_DIR}/${filename}_SneakyFPV.png"
    
    echo "Converting: $filename"

    # Convert the image with the following steps:
    convert "$file" -depth 4 -colors 16 "$output_file"

    echo "Saved to: $output_file"

    # Add the output file to the list of converted files
    converted_files+=("$output_file")
done

# Output the list of converted files
echo "✅ All files have been converted. The following files were generated:"
for file in "${converted_files[@]}"; do
    echo "$file"
done
