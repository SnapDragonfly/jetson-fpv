#!/bin/bash

# Function to pause and wait for user input
pause() {
    echo "Press any key (or Enter) to continue, or 'q' to quit..."
    while true; do
        # Read a single keypress (including Enter)
        read -n1 -s key
        if [[ -z "$key" ]]; then
            # If Enter is pressed, $key is empty
            echo -e "\nContinuing..."
            break
        elif [[ "$key" == "q" || "$key" == "Q" ]]; then
            echo -e "\nExiting..."
            exit 0
        else
            echo -e "\nContinuing..."
            break
        fi
    done
}

echo "################################################################################"
echo "# Please be carefull, as the script is NOT fully tested.                       #"
echo "# If you have met any issue, please do step by step.                           #"
echo "# If you can't solve the issue by you self, then you can come to below links:  #"
echo "# https://github.com/SnapDragonfly/jetson-fpv/issues                           #"
echo "################################################################################"

# Check if whiptail is installed
if ! command -v whiptail &> /dev/null; then
    echo "whiptail is not installed. Please install it first: sudo apt install whiptail"
    exit 1
fi

pause

# Display menu and get user selections
OPTIONS=$(whiptail --title "Jetson FPV Installation Menu" --checklist \
"Select the steps to execute (use Space to select, Tab to switch, Enter to confirm):" 20 78 15 \
"1" "Step 1: install basic components" OFF \
"2" "Step 2: install opencv with cuda" OFF \
"3" "Step 3: install jetson-inference" OFF \
"4" "Step 4: install jetson-utils" OFF \
"5.1" "Step 5.1: install rtl8812au" OFF \
"5.2" "Step 5.2: install wfb-ng" OFF \
"6.1" "Step 6.1: install pytorch" OFF \
"6.2" "Step 6.2: install pyCUDA" OFF \
"7" "Step 7: install yolo" OFF \
"8" "Step 8: install deepstream" OFF \
"9" "Step 9: install onnxruntime" OFF \
"10.1" "Step 10.1: install msposd" OFF \
"10.2" "Step 10.2: install deepstream-yolo" OFF \
"10.3" "Step 10.3: install ByteTrack" OFF \
"11" "Step 11: [Unsupported] install adaptive link" OFF \
3>&1 1>&2 2>&3)

# Exit if the user cancels
if [ $? -ne 0 ]; then
    echo "Operation canceled."
    exit 0
fi

# Split the options into an array
CHOICES=$(echo $OPTIONS | tr -d '"')

# Execute the corresponding script for each selected option
for CHOICE in $CHOICES; do
    case $CHOICE in
        1)
            echo "# Step 1: install basic components ..."
            ./install_jetson-board.sh
            ;;
        2)
            echo "# Step 2: install opencv with cuda ..."
            ./install_opencv.sh
            ;;
        3)
            echo "# Step 3: install jetson-inference ..."
            ./install_jetson-inference.sh
            ;;
        4)
            echo "# Step 4: install jetson-utils ..."
            ./install_jetson-utils.sh
            ;;
        5.1)
            echo "# Step 5.1: install rtl8812au ..."
            ./install_rtl8812au.sh
            ;;
        5.2)
            echo "# Step 5.2: install wfb-ng ..."
            ./install_wfb-ng.sh
            ;;
        6.1)
            echo "# Step 6.1: install pytorch ..."
            ./install_pytorch.sh
            ;;
        6.2)
            echo "# Step 6.2: install pyCUDA ..."
            ./install_pycuda.sh
            ;;
        7)
            echo "# Step 7: install yolo ..."
            ./install_yolo.sh
            ;;
        8)
            echo "# Step 8: install deepstream ..."
            ./install_deepstream.sh
            ;;
        9)
            echo "# Step 9: install onnxruntime ..."
            ./install_onnxruntime.sh
            ;;
        10.1)
            echo "# Step 10.1: install msposd ..."
            ./install_msposd.sh
            ;;
        10.2)
            echo "# Step 10.2: install deepstream-yolo ..."
            ./install_deepstream-yolo.sh
            ;;
        10.3)
            echo "# Step 10.3: install ByteTrack ..."
            ./install_bytetrack.sh
            ;;
        11)
            echo "# Step 11: [Unsupported] install adaptive link ..."
            ;;
        *)
            echo "Unknown option: $CHOICE"
            ;;
    esac
done

echo "All selected tasks have been completed!"

echo "################################################################################"
echo "# TIPS for enjoy jetson FPV                                                    #"
echo "# 1. download jetson-inference                                                 #"
echo "#   ==> $ cd module/jetson-inference/tools/                                    #"
echo "#   ==> $ ./download-models.sh                                                 #"
echo "#                                                                              #"
echo "#                                                                              #"
echo "################################################################################"