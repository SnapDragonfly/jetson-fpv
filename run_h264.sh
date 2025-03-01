#!/bin/bash

# Check if the correct number of arguments is provided
if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <viewer|pyviewer|gstreamer|dstrack>"
    exit 1
fi

# Set the MODE variable to the first argument
MODE=$1

# Help function to provide usage instructions
show_help() {
    echo "Usage: $0 <viewer|pyviewer|gstreamer|dstrack>"
    echo
    echo "Arguments:"
    echo "  viewer       Run the viewer mode"
    echo "  pyviewer     Run the Python viewer mode"
    echo "  gstreamer    Run the gstreamer mode"
    echo "  dstrack      Run the dstrack mode"
    echo
    echo "Example usage:"
    echo "  $0 pyviewer"
    echo "  $0 gstreamer"
}

# Choose the command to run based on the argument
case "$MODE" in
    viewer)
        sudo ./wrapper.sh viewer start
        ;;
    pyviewer)
        sudo ./wrapper.sh pyviewer start
        ;;
    gstreamer)
        sudo ./wrapper.sh gstreamer start
        ;;
    dstrack)
        sudo ./wrapper.sh dstrack start
        ;;
    *)
        echo "Invalid argument."
        show_help
        exit 1
        ;;
esac

