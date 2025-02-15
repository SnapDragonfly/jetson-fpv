#!/bin/bash

# Cast all printf info to NULL
CMD_NULL=""
IFNAME=$(wfb-nics)

# PID files for tracking processes
MSPOSD_PIDFILE="/var/run/msposd.pid"
WFB_PIDFILE="/var/run/wfb.pid"
IMAGENET_PIDFILE="/var/run/imagenet.pid"

# commands for wrapper
# wfb_rx -p 16 -i 7669206 -u 14551 -K /etc/gs.key wlan1
CMD_WFBRX="wfb_rx -p 16 -i 7669206 -u 14551 -K /etc/gs.key $IFNAME"
# ./msposd --master 127.0.0.1:14551 --osd -r 50 --ahi 1 --matrix 11
CMD_MSPOSD="./msposd --master 127.0.0.1:14551 --osd -r 50 --ahi 0 --matrix 11"
# imagenet --input-codec=h265 rtp://@:5600
CMD_IMAGENET="imagenet rtp://@:5600"

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
    echo ${CMD_IMAGENET}
    # Check if imagenet is running and print PID
    if ps aux | grep "${CMD_IMAGENET}" | grep -v grep; then
        export DISPLAY=:0
        IMAGENET_PID=$(ps aux | grep "${CMD_IMAGENET}" | grep -v grep | awk '{print $2}')
        echo "imagenet is running with PID: $IMAGENET_PID"
    else
        echo "imagenet is not running."
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

    # Step 3: Start imagenet script
    echo "Starting imagenet..."
    export DISPLAY=:0
    OUTPUT_FILE="file://$(date +"%Y-%m-%d_%H-%M-%S").mp4"
    CMD_IMAGENET="${CMD_IMAGENET} $@ --output-encoder=v4l2 ${OUTPUT_FILE}"
    echo ${CMD_IMAGENET}
    ${CMD_IMAGENET} $@ ${CMD_NULL} &
    echo $! > $IMAGENET_PIDFILE
    sleep 2 # initialization

    # Step 4: Start msposd (OSD drawing)
    echo "Starting msposd..."
    export DISPLAY=:0
    cd ./utils/msposd
    echo ${CMD_MSPOSD}
    ${CMD_MSPOSD} ${CMD_NULL} &
    echo $! > $MSPOSD_PIDFILE
    cd ../../
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

    # Step 3: Start imagenet script
    echo "Starting imagenet..."
    export DISPLAY=:0
    OUTPUT_FILE="file://$(date +"%Y-%m-%d_%H-%M-%S").mp4"
    CMD_IMAGENET="${CMD_IMAGENET} $@ --output-encoder=v4l2 ${OUTPUT_FILE}"
    echo ${CMD_IMAGENET}
    ${CMD_IMAGENET} $@ ${CMD_NULL} &
    echo $! > $IMAGENET_PIDFILE
    sleep 2 # initialization

    echo "${MODULE_NAME} started."
}

# Stop the module
stop() {
    if [ -e "${LOCK_DIR}/${MODULE_NAME}.lock" ]; then
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

        if [ -f "$IMAGENET_PIDFILE" ]; then
            kill -s SIGINT $(cat $IMAGENET_PIDFILE)
            sleep 5
            if ps aux | grep "${CMD_IMAGENET}" | grep -v grep; then
                IMAGENET_PID=$(ps aux | grep "${CMD_IMAGENET}" | grep -v grep | awk '{print $2}')
                echo "stabilizer is still running with PID: $IMAGENET_PID"
                kill -s SIGTERM $IMAGENET_PID
            fi
            sleep 1
            rm -f $IMAGENET_PIDFILE
            echo "imagenet stopped."
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
        if [ -f "$IMAGENET_PIDFILE" ] && ps -p $(cat $IMAGENET_PIDFILE) > /dev/null; then
            echo "imagenet is running with PID: $(cat $IMAGENET_PIDFILE)"
        else
            echo "imagenet is not running."
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
    CMD_IMAGENET_HELP="imagenet --help"
    ${CMD_IMAGENET_HELP}
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
