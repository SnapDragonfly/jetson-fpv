#!/bin/bash

source ./scripts/common/progress.sh
source ./scripts/common/common.sh

# Ensure the script is run as root or with sudo
if [ "$(id -u)" -ne 0 ] && [ -z "$SUDO_USER" ]; then
    echo "You must run this script as root or with sudo."
    exit 1
fi

# Parse command-line arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --verbose)
      verbose=1
      shift ;;  # Move to next argument

    -v)
      verbose=1
      shift ;;  # Move to next argument

    --iwlist)
      iwlist=1
      shift ;;  # Move to next argument

    -i)
      iwlist=1
      shift ;;  # Move to next argument

    *)
      # If no recognized flag is found, set INTERFACE to the first argument
      INTERFACE=$1
      shift ;;  # Move to next argument
  esac
done

# Check if the WiFi interface is provided as an argument
if [ -z "$INTERFACE" ]; then
    echo "Usage: $0 <interface>"
    exit 1
fi

echo "Scanning Wi-Fi Signals on Interface: $INTERFACE ..."
echo "-------------------------------------------"

iwlist_scan() {
    local IFACE=$1
    # Preset WiFi to managed mode, which is used to scan WiFi channels
    MODE=$(iw dev "$IFACE" info | awk '/type/ {print $2}')

    if [[ "$MODE" == "managed" ]]; then
        echo "Wi-Fi is in managed mode"
    else
        echo "Wi-Fi in $MODE , reset managed mode."
        sudo ip link set "$IFACE" down
        sudo iw dev "$IFACE" set type managed
        sudo ip link set "$IFACE" up
    fi

    # Perform WiFi scan and extract relevant lines
    RAW_SCAN=$(sudo iwlist "$IFACE" scan | grep Frequency | sort | uniq -c | sort -n)
    # Format the RAW_SCAN content
    RAW_SCAN=$(echo "$RAW_SCAN" | sed 's/^[[:space:]]*\([[:digit:]]*\)[[:space:]]*Frequency:/Frequency:/' )

    if [[ $verbose -eq 1 ]]; then
        echo "Raw scan result:"
        echo "$RAW_SCAN"
    fi

    extract_frequency() {
        # Input format: 3                     Frequency:5.745 GHz (Channel 149)
        local str_line="$1"

        # Use sed to extract the number after the comma (,) and discard the rest
        local value=$(echo "$str_line" | sed -n 's/.*Frequency:\([0-9]*\.[0-9]*\) GHz.*/\1/p')

        # Output the extracted value (e.g., 5.745)
        echo "$value"
    }

    extract_channel() {
        # Input format: 3                     Frequency:5.745 GHz (Channel 149)
        local str_line="$1"

        # Use sed to extract the number after the comma (,) and discard the rest
        local value=$(echo "$str_line" | sed -n 's/.*Channel \([0-9]*\).*/\1/p')

        # Output the extracted value (e.g., 149)
        echo "$value"
    }

    convert_to_channel() {
        frequency=$1

        # 2.4 GHz Band: Channel 1-14
        if (( $(echo "$frequency >= 2.412 && $frequency <= 2.472" | bc -l) )); then
            # Channel calculation for 2.4 GHz (frequencies in the range 2.412-2.472 GHz)
            channel=$(echo "($frequency - 2.412) / 0.005 + 1" | bc -l)
            # Convert to integer and format output
            printf "  --> 2.4 GHz Channel: suspect %d\n" ${channel%.*}

        # 5 GHz Band: Channels 36-165
        elif (( $(echo "$frequency >= 5.180 && $frequency <= 5.825" | bc -l) )); then
            # 5 GHz Band for channels 36 to 64 (5.180 GHz - 5.320 GHz)
            if (( $(echo "$frequency >= 5.180 && $frequency <= 5.320" | bc -l) )); then
                channel=$(echo "($frequency - 5.180) / 0.020 + 36" | bc -l)
                # Convert to integer and format output
                printf "  --> 5 GHz Channel (36-64): suspect %d\n" ${channel%.*}
            # 5 GHz Band for channels 100 to 144 (5.500 GHz - 5.740 GHz)
            elif (( $(echo "$frequency >= 5.500 && $frequency <= 5.740" | bc -l) )); then
                channel=$(echo "($frequency - 5.500) / 0.020 + 100" | bc -l)
                # Convert to integer and format output
                printf "  --> 5 GHz Channel (100-144): suspect %d\n" ${channel%.*}
            # 5 GHz Band for channels 149 to 165 (5.745 GHz - 5.825 GHz)
            elif (( $(echo "$frequency >= 5.745 && $frequency <= 5.825" | bc -l) )); then
                channel=$(echo "($frequency - 5.745) / 0.020 + 149" | bc -l)
                # Convert to integer and format output
                printf "  --> 5 GHz Channel (149-165): suspect %d\n" ${channel%.*}
            fi
        else
            echo "Frequency not in valid Wi-Fi bands."
        fi
    }

    # Declare arrays globally
    declare -a frequencies
    declare -a channels

    # Create empty arrays to hold frequencies and channels
    frequencies=()
    channels=()

    # Create temporary files to store frequencies and channels
    temp_file_freq=$(mktemp)
    temp_file_channel=$(mktemp)

    # Process each line and extract frequency and channel
    echo "$RAW_SCAN" | while read -r line; do
        frequency=$(extract_frequency "$line")
        frequencies+=($frequency)

        channel=$(extract_channel "$line")
        channels+=($channel)

        # Append frequency and channel to temporary files
        echo "$frequency" >> "$temp_file_freq"
        echo "$channel" >> "$temp_file_channel"
    done

    # After loop, read the temporary files and assign values to global arrays
    while IFS= read -r freq; do
        frequencies+=("$freq")
    done < "$temp_file_freq"

    while IFS= read -r ch; do
        channels+=("$ch")
    done < "$temp_file_channel"

    # Clean up temporary files
    rm -f "$temp_file_freq" "$temp_file_channel"

    # Debug: Print out the contents of frequencies and channels arrays
    # echo "Frequencies: ${frequencies[@]}"
    # echo "Channels: ${channels[@]}"

    # Combine channels and frequencies into one array for sorting
    combined=()
    for i in "${!channels[@]}"; do
        combined+=("${frequencies[$i]} ${channels[$i]}")
    done

    # Sort combined array based on Channel (first column)
    sorted_combined=$(for entry in "${combined[@]}"; do echo "$entry"; done | sort -n)

    # Display extracted frequencies and channels
    echo "WiFi List(${#combined[@]} Signals):"
    # Debug: Print out the sorted contents
    while read -r line; do
        #echo
        #echo "1#$line#"
        frequency=$(echo "$line" | awk '{print $1}')
        channel=$(echo "$line" | awk '{print $2}')
        #echo "11#$channel#"
        #echo "12#$frequency#"
        if [ -z "$channel" ]; then
            printf "Channel Nan Frequency %-5.3f\n" "$frequency"
            convert_to_channel $frequency
        else
            printf "Channel %-3d Frequency %-5.3f\n" "$channel" "$frequency"
        fi
    done <<< "$sorted_combined"

    if [[ $verbose -eq 1 ]]; then
        print_table frequencies 5
        print_table channels 5
    fi
}

tcpdump_scan() {
    IFACE=${1}  # Get interface from command line argument, default is wlx0c9160035b62

    # Define 2.4GHz and 5.8GHz frequency channels
    CHANNELS_24G=(1 2 3 4 5 6 7 8 9 10 11)
    FREQ_24G=(2.412 2.417 2.422 2.427 2.432 2.437 2.442 2.447 2.452 2.457 2.462)

    CHANNELS_5G=(36 40 44 48 52 56 60 64 100 104 108 112 116 120 124 128 132 136 140 149 153 157 161 165)
    FREQ_5G=(5.180 5.200 5.220 5.240 5.260 5.280 5.300 5.320 5.500 5.520 5.540 5.560 5.580 5.600 5.620 5.640 5.660 5.680 5.700 5.745 5.765 5.785 5.805 5.825)

    declare -a RESULTS

    # Scan each 2.4GHz channel
    echo "Scanning Wi-Fi 2.4GHz channel ..."
    for i in "${!CHANNELS_24G[@]}"; do
        echo -ne "Processing: $(progress_bar $((i+1)) ${#CHANNELS_24G[@]} 20 '=')\r" >&2

        sudo iw dev $IFACE set channel ${CHANNELS_24G[$i]} 2>/dev/null
        COUNT=$(sudo timeout 3s tcpdump -i $IFACE -c 5 -q 2>/dev/null | wc -l)
        if [ "$COUNT" -gt 0 ]; then
            RESULTS+=("Channel ${CHANNELS_24G[$i]}  Frequency ${FREQ_24G[$i]}")
        fi
    done

    # Scan each 5.8GHz channel
    echo
    echo "Scanning Wi-Fi 5.8GHz channel ..."
    for i in "${!CHANNELS_5G[@]}"; do
        echo -ne "Processing: $(progress_bar $((i+1)) ${#CHANNELS_5G[@]} 20 '=')\r" >&2

        sudo iw dev $IFACE set channel ${CHANNELS_5G[$i]} 2>/dev/null
        COUNT=$(sudo timeout 3s tcpdump -i $IFACE -c 5 -q 2>/dev/null | wc -l)
        if [ "$COUNT" -gt 0 ]; then
            RESULTS+=("Channel ${CHANNELS_5G[$i]}  Frequency ${FREQ_5G[$i]}")
        fi
    done

    # Output results
    echo
    echo "WiFi List (${#RESULTS[@]} Signals):"
    for LINE in "${RESULTS[@]}"; do
        echo "$LINE"
    done
}

if [[ $iwlist -eq 1 ]]; then
    iwlist_scan $INTERFACE
else
    tcpdump_scan $INTERFACE
fi

