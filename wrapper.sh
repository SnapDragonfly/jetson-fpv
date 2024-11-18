#!/bin/bash

LOCK_DIR="/tmp/module_locks"
MODULES=("stabilizer" "viewer" "imagenet" "detectnet" "segnet" "posenet")

# Ensure script runs as root or with sudo
if [ "$(id -u)" -ne 0 ] && [ -z "$SUDO_USER" ]; then
    echo "You must run this script as root or with sudo."
    exit 1
fi

# Create lock directory if it doesn't exist
mkdir -p "$LOCK_DIR"

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
    for module in "${MODULES[@]}"; do
        echo "  $module"
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

# Start a module
start_module() {
    if ! is_valid_module "$1"; then return 1; fi

    if is_any_module_running; then
        echo "Cannot start $1. Another module is running."
        return 1
    fi

    if is_module_running "$1"; then
        echo "Module $1 is already running."
    else
        echo "Starting module $1..."
        touch "${LOCK_DIR}/$1.lock"
        "./scripts/$1.sh" start || echo "Failed to start $1."
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
        echo "Module $1 is not running."
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
        help
        ;;
    *)
        execute_module_command "$@"
        ;;
esac
