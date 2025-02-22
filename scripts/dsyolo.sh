#!/bin/bash

source ./scripts/common/speedup.sh

# Cast all printf info to NULL
CMD_NULL=""
IFNAME=$(wfb-nics)

# PID files for tracking processes
MSPOSD_PIDFILE="/var/run/msposd.pid"
DSYOLO_PIDFILE="/var/run/dsyolo.pid"
WFB_PIDFILE="/var/run/wfb.pid"

# commands for wrapper
# wfb_rx -p 16 -i 7669206 -u 14551 -K /etc/gs.key wlan1
CMD_WFBRX="wfb_rx -p 16 -i 7669206 -u 14551 -K /etc/gs.key $IFNAME"
# ./msposd --master 127.0.0.1:14551 --osd -r 50 --ahi 1 --matrix 11
CMD_MSPOSD="./msposd --master 127.0.0.1:14551 --osd -r 50 --ahi 0 --matrix 11 --subtitle ../../"
# deepstream-app -c source_config_yolov8n.txt
CMD_DSYOLO="deepstream-app"

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
    echo ${CMD_DSYOLO}
    # Check if dsyolo is running and print PID
    if ps aux | grep "${CMD_DSYOLO}" | grep -v grep; then
        export DISPLAY=:0
        DSYOLO_PID=$(ps aux | grep "${CMD_DSYOLO}" | grep -v grep | awk '{print $2}')
        echo "dsyolo is running with PID: $DSYOLO_PID"
    else
        echo "dsyolo is not running."
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
    sudo systemctl status wifibroadcast@gs
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

    # Well, default SDL2 is 2.0.0
    # But I have installed SDL2 2.30.9, then the mess is here
    export LD_PRELOAD=/lib/aarch64-linux-gnu/libGLdispatch.so.0

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

    # Step 5: Start dsyolo script
    echo "Starting dsyolo..."
    #OUTPUT_FILE="file://$(date +"%Y-%m-%d_%H-%M-%S").mp4"
    #CMD_DSYOLO="${CMD_DSYOLO} ${OUTPUT_FILE} --input-codec=h265 $@"
    if [ $# -eq 0 ]; then
        CMD_DSYOLO="${CMD_DSYOLO} -c source_config_yolov8n.txt"
    else
        CMD_DSYOLO="${CMD_DSYOLO} -c $@"
    fi
    echo ${CMD_DSYOLO}
    cd utils/dsyolo
    ${CMD_DSYOLO} ${CMD_NULL} &
    echo $! > $DSYOLO_PIDFILE
    cd ../..
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

    # Well, default SDL2 is 2.0.0
    # But I have installed SDL2 2.30.9, then the mess is here
    export LD_PRELOAD=/lib/aarch64-linux-gnu/libGLdispatch.so.0
    
    # Step 3: Start dsyolo script
    echo "Starting dsyolo..."
    speedup
    export DISPLAY=:0
    #OUTPUT_FILE="file://$(date +"%Y-%m-%d_%H-%M-%S").mp4"
    #CMD_DSYOLO="${CMD_DSYOLO} ${OUTPUT_FILE} --input-codec=h265 $@"
    if [ $# -eq 0 ]; then
        CMD_DSYOLO="${CMD_DSYOLO} -c source_config_yolov8n.txt"
    else
        CMD_DSYOLO="${CMD_DSYOLO} -c $@"
    fi
    echo ${CMD_DSYOLO}
    cd utils/dsyolo
    ${CMD_DSYOLO} ${CMD_NULL} &
    echo $! > $DSYOLO_PIDFILE
    cd ../..
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

        if [ -f "$DSYOLO_PIDFILE" ]; then
            kill -s SIGINT $(cat $DSYOLO_PIDFILE)
            sleep 5
            if ps aux | grep "${CMD_DSYOLO}" | grep -v grep; then
                DSYOLO_PID=$(ps aux | grep "${CMD_DSYOLO}" | grep -v grep | awk '{print $2}')
                echo "dsyolo is still running with PID: $DSYOLO_PID"
                kill -s SIGTERM $DSYOLO_PID
            fi
            sleep 1
            rm -f $DSYOLO_PIDFILE
            echo "dsyolo stopped."
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
        sleep 1

        echo "${MODULE_NAME} stopped."
    else
        echo "Module ${MODULE_NAME} is not running. Cannot stop."
    fi
}

# Show the status of the module
status() {
    if [ -e "${LOCK_DIR}/${MODULE_NAME}.lock" ]; then
        echo "Module ${MODULE_NAME} is running."

        # Check if each process is running based on PID files and display their PIDs
        echo "Checking status of all processes..."

        echo ""
        if [ -f "$MSPOSD_PIDFILE" ] && ps -p $(cat $MSPOSD_PIDFILE) > /dev/null; then
            echo "msposd is running with PID: $(cat $MSPOSD_PIDFILE)"
        else
            echo "msposd is not running."
        fi

        echo ""
        if [ -f "$DSYOLO_PIDFILE" ] && ps -p $(cat $DSYOLO_PIDFILE) > /dev/null; then
            echo "dsyolo is running with PID: $(cat $DSYOLO_PIDFILE)"
        else
            echo "dsyolo is not running."
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
    CMD_YOLO_HELP="deepstream-app --help-all"
    ${CMD_YOLO_HELP}
    echo "Test Options:"
    echo "  1-> source_config_yolov8n.txt (default)"
    echo "  2-> source_config_yolov8s.txt"
    echo "  3-> source_config_yolov4.txt"
    echo "  4-> source_config_yolov8n_BYTETrack.txt"
    echo "  5-> source_config_yolov8n_nvDCF.txt"
}

# Test the module
test() {
    # Create lock file to indicate the module is running
    echo "Testing module ${MODULE_NAME}..."

    start ${@:2}
}

# if module supported
support() {
    echo "Not support!"
    echo "https://blog.csdn.net/lida2003/article/details/144977640"
    exit 0 #not support
    #exit 1 #support
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
