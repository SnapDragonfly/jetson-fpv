#!/bin/bash

# Ensure the target directory exists
DST_DIR="utils/dsyolo"
mkdir -p "$DST_DIR"

# Function to display help information
function show_help() {
  echo "Usage: $0 [command]"
  echo "Commands:"
  echo "  yolov4    Download YOLOv4 configuration and weights if not already present."
  echo "  help      Show this help message."
}

# Function to check file validity and handle incomplete downloads
function verify_file() {
  local file=$1
  local url=$2

  # Check if the file exists but is empty
  if [[ -f "$file" && ! -s "$file" ]]; then
    echo "Warning: $file exists but is empty. Redownloading..."
    rm -f "$file"
  fi

  # Download the file if it does not exist
  if [[ ! -f "$file" ]]; then
    echo "Downloading $(basename "$file")..."
    wget --show-progress "$url" -O "$file"
    if [[ $? -ne 0 ]]; then
      echo "Error: Failed to download $(basename "$file")."
      exit 1
    fi
  else
    echo "$(basename "$file") already exists and is valid. Skipping download."
  fi
}

# Function to download YOLOv4 configuration and weights
YOLOV4_CONFIG_URL="https://raw.githubusercontent.com/AlexeyAB/darknet/master/cfg/yolov4.cfg"
YOLOV4_WEIGHTS_URL="https://github.com/AlexeyAB/darknet/releases/download/darknet_yolo_v3_optimal/yolov4.weights"
YOLOV4_CONFIG_FILE="$DST_DIR/yolov4.cfg"
YOLOV4_WEIGHTS_FILE="$DST_DIR/yolov4.weights"
function download_yolov4() {
  verify_file "$YOLOV4_CONFIG_FILE" "$YOLOV4_CONFIG_URL"
  verify_file "$YOLOV4_WEIGHTS_FILE" "$YOLOV4_WEIGHTS_URL"
}

# Main logic
case "$1" in
  yolov4)
    download_yolov4
    ;;
  help|"")
    show_help
    ;;
  *)
    echo "Unknown command: $1"
    show_help
    exit 1
    ;;
esac

