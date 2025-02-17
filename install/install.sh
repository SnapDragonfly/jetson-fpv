#!/bin/bash

source ../scripts/common/dir.sh

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

# Function to execute Step 5: install RTL8812au and wfb-ng
install_step_5() {
    # Submenu for step 5
    SUBOPTIONS=$(whiptail --title "Step 5: install RTL8812au and wfb-ng" --checklist \
    "Select the sub-steps to execute:" 20 78 15 \
    "5.1" "Step 5.1: install rtl8812au" OFF \
    "5.2" "Step 5.2: install wfb-ng" OFF \
    3>&1 1>&2 2>&3)

    # Execute selected sub-steps
    for SUBCHOICE in $(echo $SUBOPTIONS | tr -d '"'); do
        case $SUBCHOICE in
            5.1)
                echo "# Step 5.1: install rtl8812au ..."
                ./install_rtl8812au.sh
                ;;
            5.2)
                echo "# Step 5.2: install wfb-ng ..."
                ./install_wfb-ng.sh
                ;;
            *)
                echo "Unknown option in step 5: $SUBCHOICE"
                ;;
        esac
    done
}

# Function to execute Step 6: install yolo-related modules
install_step_6() {
    # Submenu for step 6
    SUBOPTIONS=$(whiptail --title "Step 6: install yolo-related modules" --checklist \
    "Select the sub-steps to execute:" 20 78 15 \
    "6.1" "Step 6.1: install pytorch" OFF \
    "6.2" "Step 6.2: install pyCUDA" OFF \
    "6.3" "Step 6.3: install onnxruntime" OFF \
    "6.4" "Step 6.4: install YOLO" OFF \
    3>&1 1>&2 2>&3)

    # Execute selected sub-steps
    for SUBCHOICE in $(echo $SUBOPTIONS | tr -d '"'); do
        case $SUBCHOICE in
            6.1)
                echo "# Step 6.1: install pytorch ..."
                ./install_pytorch.sh
                ;;
            6.2)
                echo "# Step 6.2: install pyCUDA ..."
                ./install_pycuda.sh
                ;;
            6.3)
                echo "# Step 6.3: install onnxruntime ..."
                ./install_onnxruntime.sh
                ;;
            6.4)
                echo "# Step 6.4: install yolo ..."
                ./install_yolo.sh
                ;;
            *)
                echo "Unknown option in step 6: $SUBCHOICE"
                ;;
        esac
    done
}

# Function to execute Step 7: install deepstream-related modules
install_step_7() {
    # Submenu for step 7
    SUBOPTIONS=$(whiptail --title "Step 7: install deepstream-related modules" --checklist \
    "Select the sub-steps to execute:" 20 78 15 \
    "7.1" "Step 7.1: install deepstream" OFF \
    "7.2" "Step 7.2: install deepstream-yolo" OFF \
    "7.3" "Step 7.3: install ByteTrack" OFF \
    3>&1 1>&2 2>&3)

    # Execute selected sub-steps
    for SUBCHOICE in $(echo $SUBOPTIONS | tr -d '"'); do
        case $SUBCHOICE in
            7.1)
                echo "# Step 7.1: install deepstream ..."
                ./install_deepstream.sh
                ;;
            7.2)
                echo "# Step 7.2: install deepstream-yolo ..."
                ./install_deepstream-yolo.sh
                ;;
            7.3)
                echo "# Step 7.3: install ByteTrack ..."
                ./install_bytetrack.sh
                ;;
            *)
                echo "Unknown option in step 7: $SUBCHOICE"
                ;;
        esac
    done
}

# Function to execute Step 8: install fpv-related modules
install_step_8() {
    # Submenu for step 8
    SUBOPTIONS=$(whiptail --title "Step 8: install fpv-related modules" --checklist \
    "Select the sub-steps to execute:" 20 78 15 \
    "8.1" "Step 8.1: install msposd" OFF \
    3>&1 1>&2 2>&3)

    # Execute selected sub-steps
    for SUBCHOICE in $(echo $SUBOPTIONS | tr -d '"'); do
        case $SUBCHOICE in
            8.1)
                echo "# Step 8.1: install msposd ..."
                ./install_msposd.sh
                ;;
            *)
                echo "Unknown option in step 8: $SUBCHOICE"
                ;;
        esac
    done
}

# Check if whiptail is installed
if ! command -v whiptail &> /dev/null; then
    echo "whiptail is not installed. Please install it first: sudo apt install whiptail"
    exit 1
fi

#pause
setup
cd -

# Display the hierarchical menu and get user selections
OPTIONS=$(whiptail --title "Jetson FPV Installation Menu" --checklist \
"Select the steps to execute (use Space to select, Tab to switch, Enter to confirm):" 20 78 15 \
"1" "Step 1: install basic components" OFF \
"2" "Step 2: install opencv with cuda" OFF \
"3" "Step 3: install jetson-inference" OFF \
"4" "Step 4: install jetson-utils" OFF \
"5" "Step 5: install RTL8812au and wfb-ng" OFF \
"6" "Step 6: install yolo-related modules" OFF \
"7" "Step 7: install deepstream-related modules" OFF \
"8" "Step 8: install fpv-related modules" OFF \
3>&1 1>&2 2>&3)

# Exit if the user cancels
if [ $? -ne 0 ]; then
    echo "Operation canceled."
    exit 1
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
        5)
            install_step_5
            ;;
        6)
            install_step_6
            ;;
        7)
            install_step_7
            ;;
        8)
            install_step_8
            ;;
        *)
            echo "Unknown option: $CHOICE"
            ;;
    esac
done

echo "All selected tasks have been completed!"
cleanup --test-warning

echo "################################################################################"
echo "# TIPS for enjoying Jetson FPV                                                #"
echo "# 1. install script                                                            #"
echo "#   ==> $ cd ./install                                                         #"
echo "#   ==> $ ./install.sh                                                         #"
echo "# 2. download jetson-inference                                                 #"
echo "#   ==> $ cd module/jetson-inference/tools/                                    #"
echo "#   ==> $ ./download-models.sh                                                 #"
echo "#                                                                              #"
echo "################################################################################"
