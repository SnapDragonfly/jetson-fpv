#!/bin/bash

# Cast all printf info to NULL
CMD_NULL=" 2>/dev/null"
CMD_KEYMONITOR="python3 ./utils/detectkey.py"

LOCK_DIR="/tmp/module_locks"

# Special Modules
MODULES_SPECIAL=("version" "wfb")
MODULE_SPECIAL_DESCRIPTIONS=(
    "    Version Module: Check depended component versions."
    "        Wfb Module: Wifibroadcast transmission module."
)

# Base Modules
MODULES_BASE=("viewer" "imagenet" "detectnet" "segnet" "posenet" "gstreamer")
MODULE_BASE_DESCRIPTIONS=(
    "     Viewer Module: Displays the video stream."
    "   Imagenet Module: Image classification using Imagenet model."
    "  Detectnet Module: Object detection using DetectNet."
    "     Segnet Module: Image segmentation using SegNet."
    "    Posenet Module: Pose estimation using PoseNet."
    "  GStreamer Module: GST pipelines to process audio and video, offering flexible, plugin-based support for playback, streaming, and media transformation."
)

# Ext Modules
MODULES_EXT=("stabilizer" "yolo" "deepstream" "dsyolo")
MODULE_EXT_DESCRIPTIONS=(
    " Stabilizer Module: Stabilizes the camera or system."
    "       Yolo Module: Real-time object detection using YOLO."
    " Deepstream Module: Framework from NVIDIA that enables video analytics and AI processing, using hardware-accelerated inference for deep learning models in real-time."
    " Deepstream + YOLO: DeepStream integrates YOLO for real-time object detection and tracking."
)

MODULES=("${MODULES_SPECIAL[@]}" "${MODULES_BASE[@]}" "${MODULES_EXT[@]}")
MODULE_DESCRIPTIONS=("${MODULE_SPECIAL_DESCRIPTIONS[@]}" "${MODULE_BASE_DESCRIPTIONS[@]}" "${MODULE_EXT_DESCRIPTIONS[@]}")


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
    echo "Usage: $0 <module_name> {start|restart|ostart|orestart|stop|status|help|<other_command>} [additional_arguments]"
    echo
    echo "Commands:"
    echo "  start           Start a module"
    echo "  restart         Restart a module"
    echo "  ostart          Start a module without msposd"
    echo "  orestart        Restart a module without msposd"
    echo "  stop            Stop a module"
    echo "  status          Check the status of a module"
    echo "  help            Display this help message"
    echo "  <other_command> Pass any other command directly to the module script, such as test etc."
    echo
    echo "Available modules" 
    echo "  Special modules:" "${MODULES_SPECIAL[@]}"
    echo "     Base modules:" "${MODULES_BASE[@]}"
    echo " Extended modules:" "${MODULES_EXT[@]}"
    echo
    for module in "${MODULES[@]}"; do
        get_module_description $module
    done
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

# Function to check if a module is special
is_special_module() {
  local module="$1"  # Input module name
  for special_module in "${MODULES_SPECIAL[@]}"; do
    if [[ "$module" == "$special_module" ]]; then
      return 0  # Return true (success) if module is special
    fi
  done
  return 1  # Return false (failure) if module is not special
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

        if is_special_module "$1"; then
            echo "Module $1 is a special module."
            CMD_KEYMONITOR="$CMD_KEYMONITOR $1 no"
        else
            echo "Module $1 is not a special module."
            CMD_KEYMONITOR="$CMD_KEYMONITOR $1 yes"
        fi

        echo $CMD_KEYMONITOR
        $CMD_KEYMONITOR
    fi
}

# Start a module without msposd
ostart_module() {
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
        "./scripts/$1.sh" ostart || echo "Failed to ostart $1."

        if is_special_module "$1"; then
            echo "Module $1 is a special module."
            CMD_KEYMONITOR="$CMD_KEYMONITOR $1 no"
        else
            echo "Module $1 is not a special module."
            CMD_KEYMONITOR="$CMD_KEYMONITOR $1 yes"
        fi

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
    # Check if the module is 'version'
    if [ "$module" = "version" ]; then
        echo "Skipping CMD_KEYMONITOR execution for module 'version'."
        echo "Executing command on module $module: $*"
        "./scripts/$module.sh" "$@"
        return 0
    fi
    echo "Executing command on module $module: $*"
    "./scripts/$module.sh" "$@"

    if is_special_module "$module"; then
        echo "Module $module is a special module."
        CMD_KEYMONITOR="$CMD_KEYMONITOR $module no"
    else
        echo "Module $module is not a special module."
        CMD_KEYMONITOR="$CMD_KEYMONITOR $module yes"
    fi

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
    restart)
        stop_module "$1"
        start_module "$1"
        ;;
    ostart)
        ostart_module "$1"
        ;;
    orestart)
        stop_module "$1"
        ostart_module "$1"
        ;;
    stop)
        stop_module "$1"
        ;;
    status)
        status_module "$1"
        ;;
    help)
        execute_module_help "$@"
        ;;
    *)
        execute_module_command "$@"
        ;;
esac
