#!/bin/bash

# Cast all printf info to NULL
CMD_NULL=""

# Define the module's lock file directory (ensure the directory exists)
LOCK_DIR="/tmp/module_locks"
MODULE_NAME=$(basename "$0" .sh)

# Start the module
start() {
    # Create lock file to indicate the module is running
    touch "${LOCK_DIR}/${MODULE_NAME}.lock"
    echo "[template] Starting module ${MODULE_NAME}..."
    
    # Add the logic to start the module here, e.g., running a specific command or script
    # Example: ./start_module_command.sh

    echo "${MODULE_NAME} started."
}

# Stop the module
stop() {
    if [ -e "${LOCK_DIR}/${MODULE_NAME}.lock" ]; then
        echo "[template] Stopping module ${MODULE_NAME}..."
        rm "${LOCK_DIR}/${MODULE_NAME}.lock"

        # Add the logic to stop the module here, e.g., killing a process or stopping a service
        # Example: kill $(pidof module_process)

        echo "${MODULE_NAME} stopped."
    else
        echo "Module ${MODULE_NAME} is not running. Cannot stop."
    fi
}

# Show the status of the module
status() {
    if [ -e "${LOCK_DIR}/${MODULE_NAME}.lock" ]; then
        echo "Module ${MODULE_NAME} is running."
    else
        echo "Module ${MODULE_NAME} is not running."
    fi
}

# Restart the module
restart() {
    stop
    start
}

# Display help
help() {
    echo "Helping module ${MODULE_NAME}..."
}

# Test the module
test() {
    # Create lock file to indicate the module is running
    echo "Testing module ${MODULE_NAME}..."

    start ${@:2}
}

# Dispatcher to handle commands
case "$1" in
    start)
        start
        ;;
    stop)
        stop
        ;;
    status)
        status
        ;;
    restart)
        restart
        ;;
    help)
        help
        ;;
    test)
        test  "$@"
        ;;
    *)
        echo "Usage: $0 {start|stop|status|restart|test}"
        exit 1
        ;;
esac
