#!/bin/bash

# Cast all printf info to NULL
CMD_NULL=" 2>/dev/null"
CMD_KEYMONITOR="python3 ./utils/detectkey.py"

LOCK_DIR="/tmp/module_locks"
MODULES=("viewer" "stabilizer" "imagenet" "detectnet" "segnet" "posenet" "yolo" "wfb" "deepstream")
MODULE_DESCRIPTIONS=(
    "     Viewer Module: Displays the video stream."
    " Stabilizer Module: Stabilizes the camera or system."
    "   Imagenet Module: Image classification using Imagenet model."
    "  Detectnet Module: Object detection using DetectNet."
    "     Segnet Module: Image segmentation using SegNet."
    "    Posenet Module: Pose estimation using PoseNet."
    "       Yolo Module: Real-time object detection using YOLO."
    "        Wfb Module: Wifibroadcast transmission module."
    " Deepstream Module: A comprehensive multimedia framework from NVIDIA that enables video analytics and AI processing, using hardware-accelerated inference for deep learning models in real-time."
)

# Ensure script runs as root or with sudo
if [ "$(id -u)" -ne 0 ] && [ -z "$SUDO_USER" ]; then
    echo "You must run this script as root or with sudo."
    exit 1
fi

# Create lock directory if it doesn't exist
mkdir -p "$LOCK_DIR"

# Function to get the description of a module
get_module_description() {
    local module_name=$1
    for i in "${!MODULES[@]}"; do
        if [[ "${MODULES[$i]}" == "$module_name" ]]; then
            echo "${MODULE_DESCRIPTIONS[$i]}"
            return
        fi
    done
    echo "Module not found."
}

# Display help information
help() {
    echo "Usage: $0 <module_name> {start|stop|status|restart|help|<other_command>} [additional_arguments]"
    echo
    echo "Commands:"
    echo "  start           Start a module"
    echo "  stop            Stop a module"
    echo "  status          Check the status of a module"
    echo "  restart         Restart a module"
    echo "  help            Display this help message"
    echo "  <other_command> Pass any other command directly to the module script"
    echo
    echo "Available modules:"
    echo
    for module in "${MODULES[@]}"; do
        #echo "  $module"
        get_module_description $module
    done

    export DISPLAY=:0

    echo
    jetson_release
    # Deepstream C/C++ SDK version
    DEEPSTREAM_VERSION_FILE="/opt/nvidia/deepstream/deepstream/version"
    if [[ -f "$DEEPSTREAM_VERSION_FILE" ]]; then
        DEEPSTREAM_VERSION=$(cat "$DEEPSTREAM_VERSION_FILE" | grep -oP '(?<=Version: ).*')
        echo "DeepStream C/C++ SDK version: $DEEPSTREAM_VERSION"
    else
        echo "DeepStream C/C++ SDK version file not found"
    fi
    echo
    echo "Python Environment:"

    # Python version
    eval "python3 --version $CMD_NULL"

    # OpenCV build information
    eval "python3 -c \"import cv2; print(cv2.getBuildInformation())\" $CMD_NULL" | grep -E "CUDA|GStreamer"

    # OpenCV version and CUDA support
    eval "python3 -c \"import cv2; print('        OpenCV version:', cv2.__version__, ' CUDA', cv2.cuda.getCudaEnabledDeviceCount() > 0)\" $CMD_NULL" | grep -v "EGL"

    # YOLO version
    YOLO_VERSION=$(eval yolo version $CMD_NULL | grep -v "EGL")
    echo "          YOLO version: $YOLO_VERSION"

    # PyTorch version
    eval "python3 -c \"import torch; print('         Torch version:', torch.__version__)\" $CMD_NULL" | grep -v "EGL"

    # Torchvision version
    eval "python3 -c \"import torchvision; print('   Torchvision version:', torchvision.__version__)\" $CMD_NULL" | grep -v "EGL"

    # Deepstream SDK version
    eval "python3 -c \"import pyds; print('DeepStream SDK version:', pyds.__version__)\" $CMD_NULL" | grep -v "EGL"
}

# Check if the module name is valid
is_valid_module() {
    for module in "${MODULES[@]}"; do
        if [ "$module" == "$1" ]; then
            return 0
        fi
    done
    echo "Invalid module: $1"
    help
    return 1
}

# Check if any module is running
is_any_module_running() {
    for module in "${MODULES[@]}"; do
        if [ -e "${LOCK_DIR}/${module}.lock" ]; then
            echo "Module ${module} is running (${LOCK_DIR}/${module}.lock found)."
            return 0
        fi
    done
    return 1
}

# Check if a specific module is running
is_module_running() {
    [ -e "${LOCK_DIR}/$1.lock" ]
}

# Start a module
start_module() {
    if ! is_valid_module "$1"; then return 1; fi

    if is_any_module_running; then
        echo "Cannot start $1. Another module is running."
        return 1
    fi

    if is_module_running "$1"; then
        echo "Module $1 is already running."
        echo "If it's NOT. Please use status check or restart the module."
    else
        echo "Starting module $1..."
        touch "${LOCK_DIR}/$1.lock"
        "./scripts/$1.sh" start || echo "Failed to start $1."
        CMD_KEYMONITOR="$CMD_KEYMONITOR $1"
        echo $CMD_KEYMONITOR
        $CMD_KEYMONITOR
    fi
}

# Stop a module
stop_module() {
    if ! is_valid_module "$1"; then return 1; fi

    if is_module_running "$1"; then
        echo "Stopping module $1..."
        "./scripts/$1.sh" stop || echo "Failed to stop $1."
        rm -f "${LOCK_DIR}/$1.lock"
    else
        echo "Module $1 is not running."
    fi
}

# Status of a module
status_module() {
    if ! is_valid_module "$1"; then return 1; fi

    if is_module_running "$1"; then
        echo "Module $1 is running."
    else
        echo "Module $1 is not running. look into now ..."
    fi
    "./scripts/$1.sh" status || echo "Failed to check $1 status."
}

# Pass additional commands to the module
execute_module_command() {
    if ! is_valid_module "$1"; then return 1; fi
    module="$1"
    shift
    echo "Executing command on module $module: $*"
    "./scripts/$module.sh" "$@"

    CMD_KEYMONITOR="$CMD_KEYMONITOR $module"
    echo $CMD_KEYMONITOR
    $CMD_KEYMONITOR
}

execute_module_help() {
    if ! is_valid_module "$1"; then return 1; fi
    module="$1"
    shift
    echo "Executing help on module $module: $*"
    "./scripts/$module.sh" "$@"
}

case "$2" in
    start)
        start_module "$1"
        ;;
    stop)
        stop_module "$1"
        ;;
    status)
        status_module "$1"
        ;;
    restart)
        stop_module "$1"
        start_module "$1"
        ;;
    help)
        execute_module_help "$@"
        ;;
    *)
        execute_module_command "$@"
        ;;
esac
