#!/bin/bash

source ./scripts/common/speedup.sh

# Cast all printf info to NULL
CMD_NULL=""
IFNAME=$(wfb-nics)

# PID files for tracking processes
MSPOSD_PIDFILE="/var/run/msposd.pid"
WFB_PIDFILE="/var/run/wfb.pid"
DETECTNET_PIDFILE="/var/run/video.pid"

# commands for wrapper
# wfb_rx -p 16 -i 7669206 -u 14551 -K /etc/gs.key wlan1
CMD_WFBRX="wfb_rx -p 16 -i 7669206 -u 14551 -K /etc/gs.key $IFNAME"
# ./msposd --master 127.0.0.1:14551 --osd -r 50 --ahi 1 --matrix 11
CMD_MSPOSD="./msposd --master 127.0.0.1:14551 --osd -r 50 --ahi 0 --matrix 11 --subtitle ../../"
# video-viewer --input-codec=h265 rtp://@:5600
CMD_DETECTNET="detectnet rtp://@:5600"

# Define the module's lock file directory (ensure the directory exists)
LOCK_DIR="/tmp/module_locks"
MODULE_NAME=$(basename "$0" .sh)

cd scripts
source common/versions.sh
cd ..

look() {
    # Look at the status of each relevant process and display their PIDs
    echo "Looking at the status of processes..."
    
    echo ""
    echo ${CMD_MSPOSD}
    # Check if msposd is running and print PID
    if ps aux | grep "${CMD_MSPOSD}" | grep -v grep; then
        export DISPLAY=:0
        MSPOSD_PID=$(ps aux | grep "${CMD_MSPOSD}" | grep -v grep | awk '{print $2}')
        echo "msposd is running with PID: $MSPOSD_PID"
    else
        echo "msposd is not running."
    fi

    echo ""
    echo ${CMD_DETECTNET}
    # Check if detectnet is running and print PID
    if ps aux | grep "${CMD_DETECTNET}" | grep -v grep; then
        export DISPLAY=:0
        DETECTNET_PID=$(ps aux | grep "${CMD_DETECTNET}" | grep -v grep | awk '{print $2}')
        echo "detectnet is running with PID: $DETECTNET_PID"
    else
        echo "detectnet is not running."
    fi

    echo ""
    echo ${CMD_WFBRX}
    # Check if wfb_rx is running and print PID
    if ps aux | grep "${CMD_WFBRX}" | grep -v grep; then
        WFB_PID=$(ps aux | grep "${CMD_WFBRX}" | grep -v grep | awk '{print $2}')
        echo "wfb_rx is running with PID: $WFB_PID"
    else
        echo "wfb_rx is not running."
    fi

    echo ""
    systemctl status wifibroadcast@gs
}

# Start the module
start() {
    # Create lock file to indicate the module is running
    touch "${LOCK_DIR}/${MODULE_NAME}.lock"
    
    # Add the logic to start the module here, e.g., running a specific command or script
    # Example: ./start_module_command.sh

    # Step 1: Start wfb (wifibroadcast)
    echo "Starting wifibroadcast..."
    sudo systemctl start wifibroadcast@gs
    sleep 3 # initialization

    # Step 2: Start extra-msposd wfb
    echo ${CMD_WFBRX}
    sudo ${CMD_WFBRX} ${CMD_NULL} &
    echo $! > $WFB_PIDFILE
    sleep 2 # initialization

    # Step 3: Pre-FPV settings
    speedup
    export DISPLAY=:0

    # Step 4: Start msposd (OSD drawing)
    echo "Starting msposd..."
    cd ./utils/msposd
    echo ${CMD_MSPOSD}
    ${CMD_MSPOSD} ${CMD_NULL} &
    echo $! > $MSPOSD_PIDFILE
    cd ../../
    sleep 2 # initialization

    # Step 5: Start detectnet script
    echo "Starting detectnet..."
    OUTPUT_FILE="file://$(date +"%Y-%m-%d_%H-%M-%S").mp4"
    CMD_DETECTNET="${CMD_DETECTNET} ${OUTPUT_FILE}"
    echo ${CMD_DETECTNET}
    ${CMD_DETECTNET} $@ ${CMD_NULL} &
    echo $! > $DETECTNET_PIDFILE
    sleep 2 # initialization

    echo "${MODULE_NAME} started."
}

# Start the module without msposd
ostart() {
    # Create lock file to indicate the module is running
    touch "${LOCK_DIR}/${MODULE_NAME}.lock"
    
    # Add the logic to start the module here, e.g., running a specific command or script
    # Example: ./start_module_command.sh

    # Step 1: Start wfb (wifibroadcast)
    echo "Starting wifibroadcast..."
    sudo systemctl start wifibroadcast@gs
    sleep 3 # initialization

    # Step 3: Start detectnet script
    echo "Starting detectnet..."
    speedup
    export DISPLAY=:0
    OUTPUT_FILE="file://$(date +"%Y-%m-%d_%H-%M-%S").mp4"
    CMD_DETECTNET="${CMD_DETECTNET} ${OUTPUT_FILE}"
    echo ${CMD_DETECTNET}
    ${CMD_DETECTNET} $@ ${CMD_NULL} &
    echo $! > $DETECTNET_PIDFILE
    sleep 2 # initialization

    echo "${MODULE_NAME} started."
}

# Stop the module
stop() {
    if [ -e "${LOCK_DIR}/${MODULE_NAME}.lock" ]; then
        echo "Stopping module ${MODULE_NAME}..."
        rm "${LOCK_DIR}/${MODULE_NAME}.lock"
        # Add the logic to stop the module here, e.g., killing a process or stopping a service
        # Example: kill $(pidof module_process)

        # Stop all processes if they are running and remove PID files
        echo "Stopping all processes..."

        if [ -f "$MSPOSD_PIDFILE" ]; then
            kill $(cat $MSPOSD_PIDFILE)
            sleep 1
            rm -f $MSPOSD_PIDFILE
            echo "msposd stopped."
        fi

        if [ -f "$DETECTNET_PIDFILE" ]; then
            kill -s SIGINT $(cat $DETECTNET_PIDFILE)
            sleep 5
            if ps aux | grep "${CMD_DETECTNET}" | grep -v grep; then
                DETECTNET_PID=$(ps aux | grep "${CMD_DETECTNET}" | grep -v grep | awk '{print $2}')
                echo "stabilizer is still running with PID: $DETECTNET_PID"
                kill -s SIGTERM $DETECTNET_PID
            fi
            sleep 1
            rm -f $DETECTNET_PIDFILE
            echo "detectnet stopped."
        fi

        if [ -f "$WFB_PIDFILE" ]; then
            # Stop wfb_rx manually if it's running
            kill $(cat $WFB_PIDFILE)
            sleep 1
            if ps aux | grep "${CMD_WFBRX}" | grep -v grep; then
                WFB_PID=$(ps aux | grep "${CMD_WFBRX}" | grep -v grep | awk '{print $2}')
                echo "wfb_rx is still running with PID: $WFB_PID"
                kill -s SIGTERM $WFB_PID
            fi
            sleep 1
            rm -f $WFB_PIDFILE

            systemctl stop wifibroadcast@gs
            echo "wifibroadcast stopped."
        fi

        echo "${MODULE_NAME} stopped."
    else
        echo "Module ${MODULE_NAME} is not running. Cannot stop."
    fi
}

# Show the status of the module
status() {
    if [ -e "${LOCK_DIR}/${MODULE_NAME}.lock" ]; then
        # Check if each process is running based on PID files and display their PIDs
        echo "Checking status of all processes..."

        echo ""
        if [ -f "$MSPOSD_PIDFILE" ] && ps -p $(cat $MSPOSD_PIDFILE) > /dev/null; then
            echo "msposd is running with PID: $(cat $MSPOSD_PIDFILE)"
        else
            echo "msposd is not running."
        fi

        echo ""
        if [ -f "$DETECTNET_PIDFILE" ] && ps -p $(cat $DETECTNET_PIDFILE) > /dev/null; then
            echo "detectnet is running with PID: $(cat $DETECTNET_PIDFILE)"
        else
            echo "detectnet is not running."
        fi

        echo ""
        if [ -f "$WFB_PIDFILE" ] && ps -p $(cat $WFB_PIDFILE) > /dev/null; then
            echo "wifibroadcast (wfb_rx) is running with PID: $(cat $WFB_PIDFILE)"
        else
            echo "wifibroadcast (wfb_rx) is not running."
        fi

        echo ""
        systemctl status wifibroadcast@gs
    else
        echo "Module ${MODULE_NAME} is not running."
        look
    fi
}

# Display help
help() {
    echo "DS Version 6.3 supported"
    CMD_DETECTNET_HELP="detectnet --help"
    ${CMD_DETECTNET_HELP}
}

# Test the module
test() {
    # Create lock file to indicate the module is running
    echo "Testing module ${MODULE_NAME}..."

    start ${@:2}
}

# Support function to check DeepStream version
support() {
    # Get the DeepStream version using the function from the utility file
    DEEPSTREAM_VERSION=$(get_deepstream_version)
    
    # Print the DeepStream version
    echo "DeepStream C/C++ SDK version: $DEEPSTREAM_VERSION"
    
    # Extract the major and minor version numbers
    MAJOR_VERSION=$(echo "$DEEPSTREAM_VERSION" | awk -F'.' '{print $1}')
    MINOR_VERSION=$(echo "$DEEPSTREAM_VERSION" | awk -F'.' '{print $2}' | sed 's/[^0-9]*//g')

    # Compare major and minor versions
    if [ "$MAJOR_VERSION" -gt 7 ] || { [ "$MAJOR_VERSION" -eq 7 ] && [ "$MINOR_VERSION" -ge 1 ]; }; then
        echo "Version >= 7.1 not supported"
        exit 0
    else
        echo "Version < 7.1 supported"
        exit 1
    fi
}

# Dispatcher to handle commands
case "$1" in
    support)
        support
        ;;
    start)
        start
        ;;
    ostart)
        ostart
        ;;
    stop)
        stop
        ;;
    status)
        status
        ;;
    help)
        help
        ;;
    test)
        test  "$@"
        ;;
    *)
        echo "Usage: $0 {support|start|ostart|stop|status|help|test}"
        exit 1
        ;;
esac
