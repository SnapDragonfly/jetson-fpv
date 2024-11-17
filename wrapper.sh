#!/bin/bash

# Define a directory to store the lock files (you can change the path if needed)
LOCK_DIR="/tmp/module_locks"

# Define available modules
MODULES=("stabilizer" "viewer" "imagenet" "detectnet" "segnet" "posenet")

# Check if the script is run as root or with sudo
if [ "$(id -u)" -eq 0 ]; then
    echo "The script is being run as root."
elif [ ! -z "$SUDO_USER" ]; then
    echo "The script is being run with sudo by $SUDO_USER."
else
    echo "You must run this script as root or with sudo."
    exit 1
fi

# Check if LOCK_DIR exists, if not, create it
if [ ! -d "$LOCK_DIR" ]; then
    echo "Lock directory does not exist, creating it..."
    mkdir -p "$LOCK_DIR"
fi

# Help function to display usage and available modules
help() {
    echo "Usage: $0 {start|stop|status|restart} <module_name>"
    echo "Available modules:"
    
    # Loop through MODULES array and print each module
    for module in "${MODULES[@]}"; do
        echo "  $module"
    done
}

# Function to check if a module is valid
is_valid_module() {
    MODULE_NAME=$1
    for module in "${MODULES[@]}"; do
        if [ "$module" == "$MODULE_NAME" ]; then
            return 0  # Valid module
        fi
    done
    echo "Invalid module: $MODULE_NAME"
    help
    return 1  # Invalid module
}

# Function to check if a module is already running
is_module_running() {
    MODULE_NAME=$1
    LOCK_FILE="${LOCK_DIR}/${MODULE_NAME}.lock"

    if [ -e "$LOCK_FILE" ]; then
        echo "Module ${MODULE_NAME} is already running."
        return 0  # Return false if the module is running
    else
        return 1  # Return true if the module is not running
    fi
}

# Function to check if any module is currently running
is_any_module_running() {
    echo "Checking if any module is currently running..."
    
    # Iterate through all lock files in the LOCK_DIR
    for lock_file in ${LOCK_DIR}/*.lock; do
        # Print the name of the current lock file being checked
        echo "Checking lock file: $lock_file"
        
        # If the lock file exists, print a debug message and return false
        if [ -e "$lock_file" ]; then
            echo "Module ${lock_file} is running (lock file found)."
            return 0  # Return false if any module is running
        fi
    done

    # If no lock files are found, print a debug message and return true
    echo "No modules are currently running."
    return 1  # Return true if no module is running
}


# Function to start the module and create the lock file
start_module() {
    MODULE_NAME=$1

    # Check if the module is valid
    if ! is_valid_module "$MODULE_NAME"; then
        return 1
    fi

    # Check if any module is already running
    if is_any_module_running; then
        echo "Cannot start ${MODULE_NAME}. Another module is running."
        return 1
    fi

    # Check if the specific module is already running
    if ! is_module_running "$MODULE_NAME"; then
        echo "Starting module ${MODULE_NAME}..."
        touch "${LOCK_DIR}/${MODULE_NAME}.lock"  # Create a lock file to indicate the module is running
        # Call the module's start function here, e.g., start_stabilizer
        ./${MODULE_NAME}.sh start
    else
        echo "Module ${MODULE_NAME} is already running. Cannot start a new one."
    fi
}

# Function to stop the module and remove the lock file
stop_module() {
    MODULE_NAME=$1

    # Check if the module is valid
    if ! is_valid_module "$MODULE_NAME"; then
        return 1
    fi

    if [ -e "${LOCK_DIR}/${MODULE_NAME}.lock" ]; then
        echo "Stopping module ${MODULE_NAME}..."
        #rm "${LOCK_DIR}/${MODULE_NAME}.lock"  # Remove the lock file
        # Call the module's stop function here, e.g., stop_stabilizer
        ./${MODULE_NAME}.sh stop
    else
        echo "Module ${MODULE_NAME} is not running."
    fi
}

# Dispatcher to handle the main commands
case "$1" in
    start)
        start_module "$2"
        ;;
    stop)
        stop_module "$2"
        ;;
    status)
        echo "Checking status of module $2..."
        # Call the module's status function here, e.g., status_stabilizer
        ./$2.sh status
        ;;
    restart)
        stop_module "$2"
        start_module "$2"
        ;;
    *)
        help
        exit 1
        ;;
esac
