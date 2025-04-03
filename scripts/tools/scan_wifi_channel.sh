#!/bin/bash

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

echo "Scanning WiFi networks on interface $INTERFACE..."

# Preset WiFi to managed mode, which is used to scan WiFi channels
MODE=$(iw dev "$INTERFACE" info | awk '/type/ {print $2}')

if [[ "$MODE" == "managed" ]]; then
    echo "Wi-Fi is in managed mode"
else
    echo "Wi-Fi in $MODE , reset managed mode."
    sudo ip link set "$INTERFACE" down
    sudo iw dev "$INTERFACE" set type managed
    sudo ip link set "$INTERFACE" up
fi

# Perform WiFi scan and extract relevant lines
RAW_SCAN=$(sudo iwlist "$INTERFACE" scan | grep Frequency | sort | uniq -c | sort -n)
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
