#!/bin/bash

source ./scripts/common/speedup.sh

# Cast all printf info to NULL
CMD_NULL=""
IFNAME=$(wfb-nics)

# PID files for tracking processes
MSPOSD_PIDFILE="/var/run/msposd.pid"
WFB_PIDFILE="/var/run/wfb.pid"
VIDEO_PIDFILE="/var/run/video.pid"

# commands for wrapper
# wfb_rx -p 16 -i 7669206 -u 14551 -K /etc/gs.key wlan1
CMD_WFBRX="wfb_rx -p 16 -i 7669206 -u 14551 -K /etc/gs.key $IFNAME"
# ./msposd --master 127.0.0.1:14551 --osd -r 50 --ahi 1 --matrix 11
CMD_MSPOSD="./msposd --master 127.0.0.1:14551 --osd -r 50 --ahi 0 --matrix 11 --subtitle ../../"
# python3 ./utils/video-viewer.py --input-codec=h265 rtp://@:5600
CMD_VIDEO="python3 ./utils/video-viewer.py rtp://@:5600"

# Define the module's lock file directory (ensure the directory exists)
LOCK_DIR="/tmp/module_locks"
MODULE_NAME=$(basename "$0" .sh)

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
    echo ${CMD_VIDEO}
    # Check if video-viewer is running and print PID
    if ps aux | grep "${CMD_VIDEO}" | grep -v grep; then
        export DISPLAY=:0
        VIDEO_PID=$(ps aux | grep "${CMD_VIDEO}" | grep -v grep | awk '{print $2}')
        echo "video-viewer is running with PID: $VIDEO_PID"
    else
        echo "video-viewer is not running."
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

    # Step 1: Start wfb (wifibroadcast)/adaptive link
    echo "Starting wifibroadcast..."
    sudo systemctl start wifibroadcast@gs
    sleep 2 # initialization
    sudo systemctl start alink_gs
    sleep 1 # initialization

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

    # Step 5: Start video-viewer script
    echo "Starting video-viewer..."
    OUTPUT_FILE="file://$(date +"%Y-%m-%d_%H-%M-%S").mp4"
    CMD_VIDEO="${CMD_VIDEO} ${OUTPUT_FILE}"
    echo ${CMD_VIDEO}
    ${CMD_VIDEO} $@ ${CMD_NULL} &
    echo $! > $VIDEO_PIDFILE
    sleep 2 # initialization

    echo "${MODULE_NAME} started."
}

# Start the module without msposd
ostart() {
    # Create lock file to indicate the module is running
    touch "${LOCK_DIR}/${MODULE_NAME}.lock"
    
    # Add the logic to start the module here, e.g., running a specific command or script
    # Example: ./start_module_command.sh

    # Step 1: Start wfb (wifibroadcast)/adaptive link
    echo "Starting wifibroadcast..."
    sudo systemctl start wifibroadcast@gs
    sleep 2 # initialization
    sudo systemctl start alink_gs
    sleep 1 # initialization

    # Step 3: Start video-viewer script
    echo "Starting video-viewer..."
    speedup
    export DISPLAY=:0
    OUTPUT_FILE="file://$(date +"%Y-%m-%d_%H-%M-%S").mp4"
    CMD_VIDEO="${CMD_VIDEO} ${OUTPUT_FILE}"
    echo ${CMD_VIDEO}
    ${CMD_VIDEO} $@ ${CMD_NULL} &
    echo $! > $VIDEO_PIDFILE
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

        if [ -f "$VIDEO_PIDFILE" ]; then
            kill -s SIGINT $(cat $VIDEO_PIDFILE)
            sleep 5
            if ps aux | grep "${CMD_VIDEO}" | grep -v grep; then
                VIDEO_PID=$(ps aux | grep "${CMD_VIDEO}" | grep -v grep | awk '{print $2}')
                echo "video-viewer is still running with PID: $VIDEO_PID"
                kill -s SIGTERM $VIDEO_PID
            fi
            sleep 1
            rm -f $VIDEO_PIDFILE
            echo "video-viewer stopped."
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

            sudo systemctl stop alink_gs
            sudo systemctl stop wifibroadcast@gs
            echo "wifibroadcast/adaptiveLink stopped."
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
        if [ -f "$VIDEO_PIDFILE" ] && ps -p $(cat $VIDEO_PIDFILE) > /dev/null; then
            echo "video-viewer is running with PID: $(cat $VIDEO_PIDFILE)"
        else
            echo "video-viewer is not running."
        fi

        echo ""
        if [ -f "$WFB_PIDFILE" ] && ps -p $(cat $WFB_PIDFILE) > /dev/null; then
            echo "wifibroadcast (wfb_rx) is running with PID: $(cat $WFB_PIDFILE)"
        else
            echo "wifibroadcast (wfb_rx) is not running."
        fi

        echo ""
        systemctl status alink_gs
        systemctl status wifibroadcast@gs
    else
        echo "Module ${MODULE_NAME} is not running."
        look
    fi
}

# Display help
help() {
    CMD_VIDEO_HELP="video-viewer --help"
    ${CMD_VIDEO_HELP}
}

# Test the module
test() {
    # Create lock file to indicate the module is running
    echo "Testing module ${MODULE_NAME}..."

    start ${@:2}
}

# if module supported
support() {
    #exit 0 #not support
    exit 1 #support
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
        test "$@"
        ;;
    *)
        echo "Usage: $0 {support|start|ostart|stop|status|help|test}"
        exit 1
        ;;
esac
