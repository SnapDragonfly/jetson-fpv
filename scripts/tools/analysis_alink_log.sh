#!/bin/bash

source ./scripts/common/progress.sh
source ./scripts/common/common.sh

verbose=0  # Default: verbose mode is off
column=10  # Default value for --column
srt_file=""

# Parse command-line arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --verbose)
      verbose=1
      shift ;;  # Move to next argument

    -v)
      verbose=1
      shift ;;  # Move to next argument

    --column)
      if [[ -n "$2" && "$2" =~ ^[0-9]+$ ]]; then
        column=$2
        shift 2  # Move past '--column' and its value
      else
        echo "Error: --column requires an integer argument."
        exit 1
      fi
      ;;

    -c)
      if [[ -n "$2" && "$2" =~ ^[0-9]+$ ]]; then
        column=$2
        shift 2  # Move past '-c' and its value
      else
        echo "Error: -c requires an integer argument."
        exit 1
      fi
      ;;

    *)
      if [[ -z "$srt_file" ]]; then
        srt_file="$1"  # Assign first non-option argument as input file
        shift
      else
        echo "Error: Multiple input files detected. Only one file is allowed."
        exit 1
      fi
      ;;
  esac
done

# Ensure input file is provided
if [[ -z "$srt_file" ]]; then
  echo "Error: Missing srt file."
  echo "Usage: $0 <filename> [--verbose] [--column <num>]"
  exit 1
fi

if [[ $verbose -eq 1 ]]; then
  echo "Verbose mode enabled with $column columns detailed distributed numbers."
fi

echo "Processing SubRip Subtitle File: $srt_file"

######################################################################
# Input srt file
######################################################################

# Verify that the srt file exists
if [ ! -f "$srt_file" ]; then
    echo "Error: File '$srt_file' not found."
    exit 1
fi

# Get the base name without the extension
base_name=$(basename "$srt_file" .srt)
dir_name=$(dirname "$srt_file")

# Check if the file has the .srt extension, if so, replace it with .csv
if [[ "$srt_file" == *.srt ]]; then
    csv_file="$dir_name/${base_name}.csv"
else
    # If no extension is present, add .csv
    csv_file="$dir_name/${srt_file}.csv"
fi

# Check if the CSV file already exists
if [[ -f "$csv_file" ]]; then
    read -p "File '$csv_file' already exists. Overwrite? (Y/N): " choice
    case "$choice" in
        [Yy]) 
            rm -f $csv_file
            ;;
        *) 
            echo "Operation aborted."
            exit 1
            ;;
    esac
fi

#./scripts/tools/remove_srt_extra_newline.sh $srt_file

######################################################################
# Functions for data extract
######################################################################

alink_record_cnt=0

# Function to extract timestamp and milliseconds
alink_time_stamp=()
extract_timestamp() {
    # Input format 0.58: 00:00:00,000 --> 00:00:00,309
    # Input format 0.60: 00:00:22,674 --> 00:00:23,676

    local timestamp_line="$1"
    local timestamp_current

    # Extract the timestamp_current part (after ' --> ') which is "00:00:00,309"
    timestamp_current=$(echo "$timestamp_line" | cut -d' ' -f3)  # Extract "00:00:00,309"

    # Replace the comma with a dot to make it Excel-friendly
    timestamp_current=$(echo "$timestamp_current" | sed 's/,/./')

    # Output the timestamp in the format hh:mm:ss.mmm
    echo "$timestamp_current"
}

# Function to extract time_elapsed
alink_time_elapsed=()
extract_profile_time_elapsed() {
    # 4s 8192 20long2 10/15 Pw50 g10.0
    # sprintf(global_profile_osd, "%lds %d %d%s%d %d/%d Pw%d g%.1f", 
    # timeElapsed, profile->setBitrate, actual_bandwidth, gi_string, mcs_index, k, n, pwr, profile->setGop);

    # Input format 0.58: 4s 8192 20long2 10/15 Pw50 g10.0
    # Input format 0.60: 2s 4096 20long0 Pw55 g10.0 8/15

    local profile_line="$1"

    if [[ "$profile_line" == *"initializing"* ]]; then
        echo "0"
        return
    fi

    # Use awk to extract the first field and remove the trailing 's'
    local timeElapsed=$(echo "$profile_line" | awk '{print $1}' | sed 's/s//')

    # Output the extracted timeElapsed value
    echo "$timeElapsed"
}

# Function to extract bitrate
alink_bitrate=()
extract_profile_bitrate() {
    # 4s 8192 20long2 10/15 Pw50 g10.0
    # sprintf(global_profile_osd, "%lds %d %d%s%d %d/%d Pw%d g%.1f", 
    # timeElapsed, profile->setBitrate, actual_bandwidth, gi_string, mcs_index, k, n, pwr, profile->setGop);

    # Input format 0.58: 4s 8192 20long2 10/15 Pw50 g10.0
    # Input format 0.60: 2s 4096 20long0 Pw55 g10.0 8/15

    local profile_line="$1"

    if [[ "$profile_line" == *"initializing"* ]]; then
        echo "0"
        return
    fi

    # Use awk to extract the second field, which represents the bitrate
    local bitrate=$(echo "$profile_line" | awk '{print $2}')

    # Output the extracted bitrate
    echo "$bitrate"
}

# Function to extract bandwidth
alink_bandwidth=()
extract_profile_bandwidth() {
    # 4s 8192 20long2 10/15 Pw50 g10.0
    # sprintf(global_profile_osd, "%lds %d %d%s%d %d/%d Pw%d g%.1f", 
    # timeElapsed, profile->setBitrate, actual_bandwidth, gi_string, mcs_index, k, n, pwr, profile->setGop);

    # Input format 0.58: 4s 8192 20long2 10/15 Pw50 g10.0
    # Input format 0.60: 2s 4096 20long0 Pw55 g10.0 8/15

    local profile_line="$1"

    if [[ "$profile_line" == *"initializing"* ]]; then
        echo "0"
        return
    fi

    # Extract the third field, which is something like '20long2'
    # Use sed to extract only the leading digits from '20long2'
    local bandwidth=$(echo "$profile_line" | awk '{print $3}' | sed 's/[^0-9].*//')

    # Output the extracted bandwidth (this should be 20)
    echo "$bandwidth"
}

# Function to extract Guard Interval
alink_gi=()
extract_profile_gi() {
    # 4s 8192 20long2 10/15 Pw50 g10.0
    # sprintf(global_profile_osd, "%lds %d %d%s%d %d/%d Pw%d g%.1f", 
    # timeElapsed, profile->setBitrate, actual_bandwidth, gi_string, mcs_index, k, n, pwr, profile->setGop);

    # Input format 0.58: 4s 8192 20long2 10/15 Pw50 g10.0
    # Input format 0.60: 2s 4096 20long0 Pw55 g10.0 8/15

    local profile_line="$1"

    if [[ "$profile_line" == *"initializing"* ]]; then
        echo "0"
        return
    fi

    # Extract the third field, which is something like '20long2'
    # Use sed to extract only the 'long' part from '20long2'
    local gi_string=$(echo "$profile_line" | awk '{print $3}' | sed 's/[0-9]*//g')

    # Output the extracted GI string (this should be 'long')
    echo "$gi_string"
}

# Function to extract Modulation and Coding Scheme
alink_mcs=()
extract_profile_mcs() {
    # 4s 8192 20long2 10/15 Pw50 g10.0
    # sprintf(global_profile_osd, "%lds %d %d%s%d %d/%d Pw%d g%.1f", 
    # timeElapsed, profile->setBitrate, actual_bandwidth, gi_string, mcs_index, k, n, pwr, profile->setGop);

    # Input format 0.58: 4s 8192 20long2 10/15 Pw50 g10.0
    # Input format 0.60: 2s 4096 20long0 Pw55 g10.0 8/15

    local profile_line="$1"

    if [[ "$profile_line" == *"initializing"* ]]; then
        echo "0"
        return
    fi

    # Extract the third field: "20long2"
    local gi_field=$(echo "$profile_line" | awk '{print $3}')

    # Extract the number after 'long' using sed (this removes everything except the number after 'long')
    local mcs_index=$(echo "$gi_field" | sed 's/.*long\([0-9]*\)/\1/')

    # Output the extracted MCS index
    echo "$mcs_index"
}

# Function to extract Coding Rate
alink_k=()
extract_profile_k() {
    # 4s 8192 20long2 10/15 Pw50 g10.0
    # sprintf(global_profile_osd, "%lds %d %d%s%d %d/%d Pw%d g%.1f", 
    # timeElapsed, profile->setBitrate, actual_bandwidth, gi_string, mcs_index, k, n, pwr, profile->setGop);

    # Input format 0.58: 4s 8192 20long2 10/15 Pw50 g10.0
    # Input format 0.60: 2s 4096 20long0 Pw55 g10.0 8/15

    local profile_line="$1"

    if [[ "$profile_line" == *"initializing"* ]]; then
        echo "0"
        return
    fi

    # Extract the fourth field: "10/15"
    local kn_field=$(echo "$profile_line" | awk '{print $6}')

    # Extract the number before the '/' using sed
    local k_value=$(echo "$kn_field" | sed 's/\/.*//')

    # Output the extracted K value
    echo "$k_value"
}

# Function to extract Spatial Streams
alink_n=()
extract_profile_n() {
    # 4s 8192 20long2 10/15 Pw50 g10.0
    # sprintf(global_profile_osd, "%lds %d %d%s%d %d/%d Pw%d g%.1f", 
    # timeElapsed, profile->setBitrate, actual_bandwidth, gi_string, mcs_index, k, n, pwr, profile->setGop);

    # Input format 0.58: 4s 8192 20long2 10/15 Pw50 g10.0
    # Input format 0.60: 2s 4096 20long0 Pw55 g10.0 8/15

    local profile_line="$1"

    if [[ "$profile_line" == *"initializing"* ]]; then
        echo "0"
        return
    fi

    # Extract the fourth field: "10/15"
    local kn_field=$(echo "$profile_line" | awk '{print $6}')

    # Extract the number after the '/' using sed
    local n_value=$(echo "$kn_field" | sed 's/.*\///')

    # Output the extracted N value
    echo "$n_value"
}

# Function to extract Power
alink_pwr=()
extract_profile_pwr() {
    # 4s 8192 20long2 10/15 Pw50 g10.0
    # sprintf(global_profile_osd, "%lds %d %d%s%d %d/%d Pw%d g%.1f", 
    # timeElapsed, profile->setBitrate, actual_bandwidth, gi_string, mcs_index, k, n, pwr, profile->setGop);

    # Input format 0.58: 4s 8192 20long2 10/15 Pw50 g10.0
    # Input format 0.60: 2s 4096 20long0 Pw55 g10.0 8/15

    local profile_line="$1"

    if [[ "$profile_line" == *"initializing"* ]]; then
        echo "0"
        return
    fi

    # Extract the fifth field: "Pw50"
    local pwr_field=$(echo "$profile_line" | awk '{print $4}')

    # Extract the number after 'Pw' using sed
    local pwr_value=$(echo "$pwr_field" | sed 's/[^0-9]*//g')

    # Output the extracted power value
    echo "$pwr_value"
}

# Function to extract Group of Pictures info: Intra-frame/Predictive frame/Bidirectional frame
alink_gop=()
extract_profile_gop() {
    # 4s 8192 20long2 10/15 Pw50 g10.0
    # sprintf(global_profile_osd, "%lds %d %d%s%d %d/%d Pw%d g%.1f", 
    # timeElapsed, profile->setBitrate, actual_bandwidth, gi_string, mcs_index, k, n, pwr, profile->setGop);

    # Input format 0.58: 4s 8192 20long2 10/15 Pw50 g10.0
    # Input format 0.60: 2s 4096 20long0 Pw55 g10.0 8/15

    local profile_line="$1"

    if [[ "$profile_line" == *"initializing"* ]]; then
        echo "0"
        return
    fi

    # Extract the sixth field: "g10.0"
    local gop_field=$(echo "$profile_line" | awk '{print $5}')

    # Remove everything except the number after 'g' using sed
    local gop_value=$(echo "$gop_field" | sed 's/[^0-9.]*//g')

    # Output the extracted GOP value
    echo "$gop_value"
}

# Function to extract OSD bitrate
alink_osd_bitrate=()
extract_regular_osd_bitrate() {
    # char global_regular_osd[64] = "&L%d0&F%d&B &C tx&Wc";
    # 2.0Mb FPS:60 CPU59% tx44c

    # Input format 0.58: 2.0Mb FPS:60 CPU59% tx44c
    # Input format 0.60: 3.5Mb FPS:60 CPU:40%,62c TX:62c

    local osd_string="$1"

    # Use sed to extract the numeric part before 'Mb' and discard the rest
    local bitrate=$(echo "$osd_string" | sed -n 's/^\([0-9]*\.[0-9]*\)Mb.*$/\1/p')

    # Output the extracted bitrate (e.g., 2.0)
    echo "$bitrate"
}

# Function to extract OSD FPS
alink_osd_fps=()
extract_regular_osd_fps() {
    # char global_regular_osd[64] = "&L%d0&F%d&B &C tx&Wc";
    # 2.0Mb FPS:60 CPU59% tx44c

    # Input format 0.58: 2.0Mb FPS:60 CPU59% tx44c
    # Input format 0.60: 3.5Mb FPS:60 CPU:40%,62c TX:62c

    local osd_string="$1"

    # Use sed to extract the number after 'FPS:' and discard the rest
    local fps=$(echo "$osd_string" | sed -n 's/.*FPS:\([0-9]*\).*/\1/p')

    # Output the extracted FPS value (e.g., 60)
    echo "$fps"
}

# Function to extract OSD CPU
alink_osd_cpu=()
extract_regular_osd_cpu() {
    # char global_regular_osd[64] = "&L%d0&F%d&B &C tx&Wc";
    # 2.0Mb FPS:60 CPU59% tx44c

    # Input format 0.58: 2.0Mb FPS:60 CPU59% tx44c
    # Input format 0.60: 3.5Mb FPS:60 CPU:40%,62c TX:62c

    local osd_string="$1"

    # Use sed to extract the number after 'CPU' and discard the '%' symbol
    local cpu=$(echo "$osd_string" | sed -n 's/.*CPU:\([0-9]*\)%.*$/\1/p')

    # Output the extracted CPU value (e.g., 59)
    echo "$cpu"
}

# Function to extract OSD CPU temperature
alink_osd_cpu_temp=()
extract_regular_osd_cpu_temp() {
    # char global_regular_osd[64] = "&L%d0&F%d&B &C tx&Wc";
    # 2.0Mb FPS:60 CPU59% tx44c

    # Input format 0.58: 2.0Mb FPS:60 CPU59% tx44c
    # Input format 0.60: 3.5Mb FPS:60 CPU:40%,62c TX:62c

    local osd_string="$1"

    # Use sed to extract the number after 'CPU' and discard the '%' symbol
    local cpu=$(echo "$osd_string" | sed -E 's/.*CPU:[0-9]+%,([0-9]+)c.*/\1/')


    # Output the extracted CPU value (e.g., 59)
    echo "$cpu"
}

# Function to extract OSD TX temperature
alink_osd_tx_temp=()
extract_regular_osd_tx_temp() {
    # char global_regular_osd[64] = "&L%d0&F%d&B &C tx&Wc";
    # 2.0Mb FPS:60 CPU59% tx44c

    # Input format 0.58: 2.0Mb FPS:60 CPU59% tx44c
    # Input format 0.60: 3.5Mb FPS:60 CPU:40%,62c TX:62c

    local osd_string="$1"

    # Use sed to extract the number after 'tx' and discard the 'c' character
    local tx_temp=$(echo "$osd_string" | sed -n 's/.*TX:\([0-9]*\)c.*$/\1/p')

    # Output the extracted temperature value (e.g., 44)
    echo "$tx_temp"
}

# Function to extract orignal score of link quality
alink_linkq=()
extract_linkq() {
    # sprintf(global_score_related_osd, "og %d, smthd %d", osd_raw_score, osd_smoothed_score);
    # og 1711, smthd 1698

    # Input format 0.58: og 1711, smthd 1698
    # Input format 0.60: linkQ 1237, smthdQ 1242

    local osd_string="$1"

    if [[ "$osd_string" == *"initializing"* ]]; then
        echo "1000"
        return
    fi

    # Use sed to extract the number after 'og' and discard the rest
    local linkq=$(echo "$osd_string" | sed -n 's/.*linkQ \([0-9]*\),.*/\1/p')

    # Output the extracted score value (e.g., 1711)
    echo "$linkq"
}

# Function to extract filtered score of link quality
alink_smthdq=()
extract_smthdq() {
    # sprintf(global_score_related_osd, "og %d, smthd %d", osd_raw_score, osd_smoothed_score);
    # og 1711, smthd 1698

    # Input format 0.58: og 1711, smthd 1698
    # Input format 0.60: linkQ 1237, smthdQ 1242

    local osd_string="$1"

    if [[ "$osd_string" == *"initializing"* ]]; then
        echo "1000"
        return
    fi

    # Use sed to extract the number after 'smthd' and discard the rest
    local smthdq=$(echo "$osd_string" | sed -n 's/.*smthdQ \([0-9]*\)/\1/p')

    # Output the extracted score value (e.g., 1698)
    echo "$smthdq"
}

# Function to extract rssi value
alink_rssi_value=()
extract_rssi_value() {
    # sprintf(global_gs_stats_osd, "rssi%d, %d\nsnr%d, %d\nfec%d", 
    # rssi1, link_value_rssi, snr1, link_value_snr, recovered);
    # snprintf(global_extra_stats_osd, sizeof(global_extra_stats_osd), "pnlt%d xtx%ld(%d) idr%d",
    # applied_penalty, global_total_tx_dropped, total_keyframe_requests_xtx, total_keyframe_requests);
    # rssi-32, 1960 \n 
    # snr24, 1462 \n 
    # fec4 pnlt0 xtx0(0) idr0

    # Input format 0.58  : rssi-32, 1960
    # Input format 0.60  : rssi-21 snr17 ants:vrx2
    # Input format 0.60.x: rssi-24 snr24 fec0 ants:vrx2

    local osd_string="$1"

    if [[ "$osd_string" == *"waiting"* ]]; then
        echo "0"
        return
    fi

    # Use sed to extract the number after 'rssi' and discard the rest
    local rssi_value=$(echo "$osd_string" | sed -n 's/.*rssi\([-0-9]*\).*/\1/p')

    # Output the extracted RSSI value (e.g., -32)
    echo "$rssi_value"
}

# Function to extract snr value
alink_snr_value=()
extract_snr_value() {
    # sprintf(global_gs_stats_osd, "rssi%d, %d\nsnr%d, %d\nfec%d", 
    # rssi1, link_value_rssi, snr1, link_value_snr, recovered);
    # snprintf(global_extra_stats_osd, sizeof(global_extra_stats_osd), "pnlt%d xtx%ld(%d) idr%d",
    # applied_penalty, global_total_tx_dropped, total_keyframe_requests_xtx, total_keyframe_requests);
    # rssi-32, 1960 \n 
    # snr24, 1462 \n 
    # fec4 pnlt0 xtx0(0) idr0

    # Input format 0.58  : snr24, 1462
    # Input format 0.60  : rssi-21 snr17 ants:vrx2
    # Input format 0.60.x: rssi-24 snr24 fec0 ants:vrx2

    local osd_string="$1"

    if [[ "$osd_string" == *"waiting"* ]]; then
        echo "0"
        return
    fi

    # Use sed to extract the number after 'snr' and discard the rest
    local snr_value=$(echo "$osd_string" | sed -n 's/.*snr\([0-9]*\).*/\1/p')

    # Output the extracted SNR value (e.g., 24)
    echo "$snr_value"
}

# Function to extract extra info: fec
alink_extra_rx_fec=()
extract_extra_fec() {
    # sprintf(global_gs_stats_osd, "rssi%d, %d\nsnr%d, %d\nfec%d", 
    # rssi1, link_value_rssi, snr1, link_value_snr, recovered);
    # snprintf(global_extra_stats_osd, sizeof(global_extra_stats_osd), "pnlt%d xtx%ld(%d) idr%d",
    # applied_penalty, global_total_tx_dropped, total_keyframe_requests_xtx, total_keyframe_requests);
    # rssi-32, 1960 \n 
    # snr24, 1462 \n 
    # fec4 pnlt0 xtx0(0) idr0

    # Input format 0.58  : fec4 pnlt0 xtx0(0) idr0
    # Input format 0.60  : pnlt-358 xtx0(0) gs_idr5 //No FEC recover packet
    # Input format 0.60.x: rssi-24 snr24 fec4 ants:vrx2

    local osd_string="$1"

    if [[ "$osd_string" == *"waiting"* ]]; then
        echo "0"
        return
    fi

    # Use sed to extract the number after 'fec' and discard the rest
    local fec_value=$(echo "$osd_string" | sed -n 's/.*fec\([0-9]*\).*/\1/p')

    # Output the extracted FEC value (e.g., 4)
    echo "$fec_value"
}

# Function to extract extra info: penalty
alink_extra_pnlt=()
extract_extra_pnlt() {
    # sprintf(global_gs_stats_osd, "rssi%d, %d\nsnr%d, %d\nfec%d", 
    # rssi1, link_value_rssi, snr1, link_value_snr, recovered);
    # snprintf(global_extra_stats_osd, sizeof(global_extra_stats_osd), "pnlt%d xtx%ld(%d) idr%d",
    # applied_penalty, global_total_tx_dropped, total_keyframe_requests_xtx, total_keyframe_requests);
    # rssi-32, 1960 \n 
    # snr24, 1462 \n 
    # fec4 pnlt0 xtx0(0) idr0

    # Input format 0.58: fec4 pnlt0 xtx0(0) idr0
    # Input format 0.60: pnlt-358 xtx0(0) gs_idr5
    local osd_string="$1"

    if [[ "$osd_string" == *"waiting"* ]]; then
        echo "0"
        return
    fi

    # Use sed to extract the number after 'pnlt' and discard the rest
    local pnlt_value=$(echo "$osd_string" | sed -n 's/.*pnlt\([+-]\?[0-9]\+\).*/\1/p')

    # Output the extracted PNLT value (e.g., -358)
    echo "$pnlt_value"
}

# Function to extract extra info: tx_dropped
alink_extra_tx_dropped=()
extract_extra_tx_dropped() {
    # sprintf(global_gs_stats_osd, "rssi%d, %d\nsnr%d, %d\nfec%d", 
    # rssi1, link_value_rssi, snr1, link_value_snr, recovered);
    # snprintf(global_extra_stats_osd, sizeof(global_extra_stats_osd), "pnlt%d xtx%ld(%d) idr%d",
    # applied_penalty, global_total_tx_dropped, total_keyframe_requests_xtx, total_keyframe_requests);
    # rssi-32, 1960 \n 
    # snr24, 1462 \n 
    # fec4 pnlt0 xtx0(0) idr0

    # Input format 0.58: fec4 pnlt0 xtx0(0) idr0
    # Input format 0.60: pnlt-358 xtx0(0) gs_idr5

    local osd_string="$1"

    # Extract the number **right after** 'xtx' (before '(')
    local tx_dropped_value=$(echo "$osd_string" | sed -n 's/.*xtx\([0-9]\+\)(.*/\1/p')

    # Output the extracted value (e.g., 35)
    echo "$tx_dropped_value"
}

declare -g alink_latest_tx_dropped=-1
declare -g adjust_tx_dropped_result
adjust_extra_tx_dropped() {
    local tx_dropped_value="$1"

    if [[ -z "$tx_dropped_value" ]]; then
        adjust_tx_dropped_result=0
        return
    fi

    if [[ $alink_latest_tx_dropped -eq -1 ]]; then
        alink_latest_tx_dropped=$tx_dropped_value
        adjust_tx_dropped_result=0
    else
        local delta_dropped_value=$((tx_dropped_value - alink_latest_tx_dropped))
        alink_latest_tx_dropped=$tx_dropped_value
        adjust_tx_dropped_result=$delta_dropped_value
    fi
}

# Function to extract extra info: tx_requested
alink_extra_tx_requested=()
extract_extra_tx_requested() {
    # sprintf(global_gs_stats_osd, "rssi%d, %d\nsnr%d, %d\nfec%d", 
    # rssi1, link_value_rssi, snr1, link_value_snr, recovered);
    # snprintf(global_extra_stats_osd, sizeof(global_extra_stats_osd), "pnlt%d xtx%ld(%d) idr%d",
    # applied_penalty, global_total_tx_dropped, total_keyframe_requests_xtx, total_keyframe_requests);
    # rssi-32, 1960 \n 
    # snr24, 1462 \n 
    # fec4 pnlt0 xtx0(0) idr0

    # Input format 0.58: fec4 pnlt0 xtx0(0) idr0
    # Input format 0.60: pnlt-358 xtx0(0) gs_idr5

    local osd_string="$1"

    # Use sed to extract the number after the '(' in 'xtx0(0)'
    local tx_requested_value=$(echo "$osd_string" | sed -n 's/.*xtx[0-9]*(\([0-9]*\)).*/\1/p')

    # Output the extracted value (e.g., 0)
    echo "$tx_requested_value"
}

declare -g alink_latest_tx_requested=-1
declare -g adjust_tx_requested_result
adjust_extra_tx_requested() {
    local tx_requested_value="$1"

    if [[ -z "$tx_requested_value" ]]; then
        adjust_tx_requested_result=0
        return
    fi

    if [[ $alink_latest_tx_requested -eq -1 ]]; then
        alink_latest_tx_requested=$tx_requested_value
        adjust_tx_requested_result=0
    else
        local delta_requested_value=$((tx_requested_value - alink_latest_tx_requested))
        alink_latest_tx_requested=$tx_requested_value
        adjust_tx_requested_result=$delta_requested_value
    fi
}

# Function to extract extra info: rx_requested
alink_extra_rx_requested=()
extract_extra_rx_requested() {
    # sprintf(global_gs_stats_osd, "rssi%d, %d\nsnr%d, %d\nfec%d", 
    # rssi1, link_value_rssi, snr1, link_value_snr, recovered);
    # snprintf(global_extra_stats_osd, sizeof(global_extra_stats_osd), "pnlt%d xtx%ld(%d) idr%d",
    # applied_penalty, global_total_tx_dropped, total_keyframe_requests_xtx, total_keyframe_requests);
    # rssi-32, 1960 \n 
    # snr24, 1462 \n 
    # fec4 pnlt0 xtx0(0) idr0

    # Input format 0.58: fec4 pnlt0 xtx0(0) idr0 
    # Input format 0.60: pnlt-358 xtx0(0) gs_idr5

    local osd_string="$1"

    # Use sed to extract the number after 'idr' and discard the rest
    local rx_requested_value=$(echo "$osd_string" | sed -n 's/.*gs_idr\([0-9]*\).*/\1/p')

    # Output the extracted value (e.g., 0)
    echo "$rx_requested_value"
}

declare -g alink_latest_rx_requested=-1
declare -g adjust_rx_requested_result
adjust_extra_rx_requested() {
    local rx_requested_value="$1"

    if [[ -z "$rx_requested_value" ]]; then
        adjust_rx_requested_result=0
        return
    fi

    if [[ $alink_latest_rx_requested -eq -1 ]]; then
        alink_latest_rx_requested=$rx_requested_value
        adjust_rx_requested_result=0
    else
        local delta_requested_value=$((rx_requested_value - alink_latest_rx_requested))
        alink_latest_rx_requested=$rx_requested_value
        adjust_rx_requested_result=$delta_requested_value
    fi
}

# Function to extract gs lost packet
alink_extra_rx_lost=()
extract_extra_rx_lost() {
    # Input format 0.60.x: rssi-56 snr21 fec11 lost4 ants:vrx4

    local osd_string="$1"

    if [[ -z "$osd_string" ]]; then
        echo "0"
        return
    fi

    if [[ "$osd_string" == *"waiting"* ]]; then
        echo "0"
        return
    fi

    # Use sed to extract the number after the comma (,) and discard the rest
    local lost_packet=$(echo "$osd_string" | sed -n 's/.*lost\([0-9]\+\).*/\1/p')

    # Output the extracted score value (e.g., 4)
    echo "$lost_packet"
}

######################################################################
# Functions for deprecated
######################################################################

# Function to extract rssi score
alink_rssi_score=()
extract_rssi_score() {
    # sprintf(global_gs_stats_osd, "rssi%d, %d\nsnr%d, %d\nfec%d", 
    # rssi1, link_value_rssi, snr1, link_value_snr, recovered);
    # snprintf(global_extra_stats_osd, sizeof(global_extra_stats_osd), "pnlt%d xtx%ld(%d) idr%d",
    # applied_penalty, global_total_tx_dropped, total_keyframe_requests_xtx, total_keyframe_requests);
    # rssi-32, 1960 \n 
    # snr24, 1462 \n 
    # fec4 pnlt0 xtx0(0) idr0

    # Input format 0.58: rssi-32, 1960
    # Input format 0.60: rssi-21 snr17 ants:vrx2 //No rssi score

    echo ""

    # local osd_string="$1"

    # # Use sed to extract the number after the comma (,) and discard the rest
    # local rssi_score=$(echo "$osd_string" | sed -n 's/.*rssi[-0-9]*,\s*\([0-9]*\).*/\1/p')

    # # Output the extracted score value (e.g., 1960)
    # echo "$rssi_score"
}

# Function to extract snr score
alink_snr_score=()
extract_snr_score() {
    # sprintf(global_gs_stats_osd, "rssi%d, %d\nsnr%d, %d\nfec%d", 
    # rssi1, link_value_rssi, snr1, link_value_snr, recovered);
    # snprintf(global_extra_stats_osd, sizeof(global_extra_stats_osd), "pnlt%d xtx%ld(%d) idr%d",
    # applied_penalty, global_total_tx_dropped, total_keyframe_requests_xtx, total_keyframe_requests);
    # rssi-32, 1960 \n 
    # snr24, 1462 \n 
    # fec4 pnlt0 xtx0(0) idr0


    # Input format 0.58: snr24, 1462
    # Input format 0.60: rssi-21 snr17 ants:vrx2 //No snr score

    echo ""

    # local osd_string="$1"  # Input string, e.g., "snr24, 1462"

    # # Use sed to extract the number after the comma (,) and discard the rest
    # local snr_score=$(echo "$osd_string" | sed -n 's/.*snr[-0-9]*,\s*\([0-9]*\).*/\1/p')

    # # Output the extracted score value (e.g., 1462)
    # echo "$snr_score"
}

######################################################################
# Functions for data export
######################################################################

export_to_csv() {
    # Define the headers (remove 'alink_' prefix and set as column names)
    local headers="time, elapsed, Kbitrate, bandwidth, gi, mcs, k, n, pwr, gop, Mbitrate, fps, cpu, temp, tx_temp, linkq, smthdq, rssi, rssi_score, snr, snr_score, fec, pnlt, tx_drop, tx_req, rx_req, rx_lost"

    # Print headers (replace 'alink_' prefix)
    echo "$headers"

    # Print record values as CSV
    for ((i = 0; i < alink_record_cnt; i++)); do
        echo -n "${alink_time_stamp[i]},"
        echo -n "${alink_time_elapsed[i]},"
        echo -n "${alink_bitrate[i]},"
        echo -n "${alink_bandwidth[i]},"
        echo -n "${alink_gi[i]},"
        echo -n "${alink_mcs[i]},"
        echo -n "${alink_k[i]},"
        echo -n "${alink_n[i]},"
        echo -n "${alink_pwr[i]},"
        echo -n "${alink_gop[i]},"
        echo -n "${alink_osd_bitrate[i]},"
        echo -n "${alink_osd_fps[i]},"
        echo -n "${alink_osd_cpu[i]},"
        echo -n "${alink_osd_cpu_temp[i]},"
        echo -n "${alink_osd_tx_temp[i]},"
        echo -n "${alink_linkq[i]},"
        echo -n "${alink_smthdq[i]},"
        echo -n "${alink_rssi_value[i]},"
        echo -n "${alink_rssi_score[i]},"
        echo -n "${alink_snr_value[i]},"
        echo -n "${alink_snr_score[i]},"
        echo -n "${alink_extra_rx_fec[i]},"
        echo -n "${alink_extra_pnlt[i]},"
        echo -n "${alink_extra_tx_dropped[i]},"
        echo -n "${alink_extra_tx_requested[i]},"
        echo -n "${alink_extra_rx_requested[i]},"
        echo    "${alink_extra_rx_lost[i]}"
    done

    # Print a newline to end the row
    echo
}

######################################################################
# Functions for data analysis
######################################################################

# Function: Check and update CPU %
alink_cpu_min=9999
alink_cpu_max=0
check_cpu() {
    local value=$1

    if [[ -z "$value" ]]; then
        return
    fi

    # Update the minimum/maximum CPU percentage
    if [[ $value -lt $alink_cpu_min ]]; then
        alink_cpu_min=$value
    fi
    if [[ $value -gt $alink_cpu_max ]]; then
        alink_cpu_max=$value
    fi
}

# Function: Check and update CPU temperature
alink_cpu_temp_min=9999
alink_cpu_temp_max=0
check_cpu_temp() {
    local value=$1

    if [[ -z "$value" ]]; then
        return
    fi

    # Update the minimum/maximum CPU temperature
    if [[ $value -lt $alink_cpu_temp_min ]]; then
        alink_cpu_temp_min=$value
    fi
    if [[ $value -gt $alink_cpu_temp_max ]]; then
        alink_cpu_temp_max=$value
    fi
}

# Function: Print CPU statistics
report_cpu() {
    echo ""
    echo "------------------------------------------"
    echo "CPU Usage  : $alink_cpu_min ~ $alink_cpu_max %"
    echo "CPU Celsius: $alink_cpu_temp_min ~ $alink_cpu_temp_max C"

    # Check if the maximum CPU usage exceeds threshold
    if [[ $alink_cpu_max -gt 70 ]]; then
        echo "!WARNING!: CPU usage exceeded 70%!"
    fi

    # Check if the maximum CPU temperature exceeds threshold
    if [[ $alink_cpu_temp_max -gt 70 ]]; then
        echo "!WARNING!: CPU temperature exceeded 70C!"
    fi
}

# Function: Check and update TX temperature
alink_tx_temp_min=9999
alink_tx_temp_max=0
check_tx_temp() {
    local value=$1

    if [[ -z "$value" ]]; then
        return
    fi

    # Update the minimum/maximum tx temperature value
    if [[ $value -lt $alink_tx_temp_min ]]; then
        alink_tx_temp_min=$value
    fi
    if [[ $value -gt $alink_tx_temp_max ]]; then
        alink_tx_temp_max=$value
    fi
}

# Function: Check and update TX power
alink_tx_power_min=9999
alink_tx_power_max=0
check_tx_power() {
    local value=$1

    if [[ -z "$value" ]]; then
        return
    fi

    # Update the minimum/maximum tx power
    if [[ $value -lt $alink_tx_power_min ]]; then
        alink_tx_power_min=$value
    fi
    if [[ $value -gt $alink_tx_power_max ]]; then
        alink_tx_power_max=$value
    fi
}

# Function: Check and update bitrate
alink_tx_bitrate_min=9999
alink_tx_bitrate_max=0
check_tx_bitrate() {
    local value=$1

    if [[ -z "$value" ]]; then
        return
    fi

    # exception case: initializing... 0/0
    if [[ "$value" == "0/0" ]]; then
        return
    fi

    # Update the minimum/maximum tx bitrate
    if [[ $value -lt $alink_tx_bitrate_min ]]; then
        alink_tx_bitrate_min=$value
    fi
    if [[ $value -gt $alink_tx_bitrate_max ]]; then
        alink_tx_bitrate_max=$value
    fi
}

# Function: Print TX statistics
report_tx() {
    echo ""
    echo "------------------------------------------"
    echo "TX   Power: $alink_tx_power_min ~ $alink_tx_power_max"
    echo "TX Celsius: $alink_tx_temp_min ~ $alink_tx_temp_max C"
    echo "TX bitrate: $alink_tx_bitrate_min ~ $alink_tx_bitrate_max kbps"

    # Check if the maximum TX temperature exceeds threshold
    if [[ $alink_tx_temp_max -gt 100 ]]; then
        echo "!WARNING!: TX temperature exceeded 100 degree Celsius"
    fi
}

# Function: Check and update linkq/smthdq link scores
alink_rssi_value_min=9999
alink_rssi_value_max=-999
alink_snr_value_min=9999
alink_snr_value_max=0
alink_linkq_min=9999
alink_linkq_max=0
alink_smthdq_min=9999
alink_smthdq_max=0
check_link_score() {
    local rssi_value=$1
    local snr_value=$2
    local linkq_value=$3
    local smthdq_value=$4

    if [[ -n "$rssi_value" ]]; then
        # Update the minimum/maximum RSSI value
        if [[ $rssi_value -lt $alink_rssi_value_min ]]; then
            alink_rssi_value_min=$rssi_value
        fi
        if [[ $rssi_value -gt $alink_rssi_value_max ]]; then
            alink_rssi_value_max=$rssi_value
        fi
    fi

    if [[ -n "$snr_value" ]]; then
        # Update the minimum/maximum SNR value
        if [[ $snr_value -lt $alink_snr_value_min ]]; then
            alink_snr_value_min=$snr_value
        fi
        if [[ $snr_value -gt $alink_snr_value_max ]]; then
            alink_snr_value_max=$snr_value
        fi
    fi

    if [[ -n "$linkq_value" ]]; then
        # Update the minimum/maximum original score
        if [[ $linkq_value -lt $alink_linkq_min ]]; then
            alink_linkq_min=$linkq_value
        fi
        if [[ $linkq_value -gt $alink_linkq_max ]]; then
            alink_linkq_max=$linkq_value
        fi
    fi

    if [[ -n "$smthdq_value" ]]; then
        # Update the minimum/maximum filtered score
        if [[ $smthdq_value -lt $alink_smthdq_min ]]; then
            alink_smthdq_min=$smthdq_value
        fi
        if [[ $smthdq_value -gt $alink_smthdq_max ]]; then
            alink_smthdq_max=$smthdq_value
        fi
    fi
}

# Function: Print link score statistics
report_link_score() {
    echo ""
    echo "------------------------------------------"
    echo "RSSI : $alink_rssi_value_min ~ $alink_rssi_value_max"
    echo "SNR  : $alink_snr_value_min ~ $alink_snr_value_max"
    echo "LinkQ: $alink_linkq_min ~ $alink_linkq_max"
    echo "smthQ: $alink_smthdq_min ~ $alink_smthdq_max"

    if [[ $verbose -eq 1 ]]; then
        print_table alink_linkq $column
        print_table alink_smthdq $column
    fi
}

# Function: Check and update link status
alink_fec_min=9999
alink_fec_max=0
alink_lost_packet_min=9999
alink_lost_packet_max=0
alink_penalty_min=0
alink_penalty_max=-999
alink_tx_dropped_min=9999
alink_tx_dropped_max=0
alink_tx_requested_min=9999
alink_tx_requested_max=0
alink_rx_requested_min=9999
alink_rx_requested_max=0
check_link_status() {
    local lost_packet=$1
    local fec=$2
    local pnlty=$3
    local tx_dropped=$4
    local tx_requested=$5
    local rx_requested=$6

    # Update min/max values only if the corresponding variable is provided
    if [[ -n "$lost_packet" ]]; then
        # If the new value is smaller or larger, update min/max
        [[ $lost_packet -lt $alink_lost_packet_min ]] && alink_lost_packet_min=$lost_packet
        [[ $lost_packet -gt $alink_lost_packet_max ]] && alink_lost_packet_max=$lost_packet
    fi

    # Update min/max values only if the corresponding variable is provided
    if [[ -n "$fec" ]]; then
        # If the new value is smaller or larger, update min/max
        [[ $fec -lt $alink_fec_min ]] && alink_fec_min=$fec
        [[ $fec -gt $alink_fec_max ]] && alink_fec_max=$fec
    fi

    if [[ -n "$pnlty" ]]; then
        # If the new value is smaller or larger, update min/max
        [[ $pnlty -lt $alink_penalty_min ]] && alink_penalty_min=$pnlty
        [[ $pnlty -gt $alink_penalty_max ]] && alink_penalty_max=$pnlty
    fi

    if [[ -n "$tx_dropped" ]]; then
        # If the new value is smaller or larger, update min/max
        [[ $tx_dropped -lt $alink_tx_dropped_min ]] && alink_tx_dropped_min=$tx_dropped
        [[ $tx_dropped -gt $alink_tx_dropped_max ]] && alink_tx_dropped_max=$tx_dropped
    fi

    if [[ -n "$tx_requested" ]]; then
        # If the new value is smaller or larger, update min/max
        [[ $tx_requested -lt $alink_tx_requested_min ]] && alink_tx_requested_min=$tx_requested
        [[ $tx_requested -gt $alink_tx_requested_max ]] && alink_tx_requested_max=$tx_requested
    fi

    if [[ -n "$rx_requested" ]]; then
        # If the new value is smaller or larger, update min/max
        [[ $rx_requested -lt $alink_rx_requested_min ]] && alink_rx_requested_min=$rx_requested
        [[ $rx_requested -gt $alink_rx_requested_max ]] && alink_rx_requested_max=$rx_requested
    fi
}

# Function: Print link statistics
report_link_status() {
    echo ""
    echo "------------------------------------------"
    echo "RX FEC      : $alink_fec_min ~ $alink_fec_max"
    echo "RX lost     : $alink_lost_packet_min ~ $alink_lost_packet_max"
    echo "TX penalty  : $alink_penalty_min ~ $alink_penalty_max"
    echo "TX dropped  : $alink_tx_dropped_min ~ $alink_tx_dropped_max"
    echo "TX requested: $alink_tx_requested_min ~ $alink_tx_requested_max"
    echo "RX requested: $alink_rx_requested_min ~ $alink_rx_requested_max"
    if [[ $verbose -eq 1 ]]; then
        print_table alink_extra_rx_fec $column
        print_table alink_extra_tx_dropped $column
        print_table alink_extra_tx_requested $column
        print_table alink_extra_rx_lost $column
        print_table alink_extra_rx_requested $column
    fi
}

######################################################################
# Functions for srt file parsing loop
######################################################################

# Function to deal with srt block messages
inconsistence_ids=()
process_block() {
    ((alink_record_cnt++))

    # check srt id consistency
    id=$(( block[0] ))
    if [[ "$alink_record_cnt" -ne "$id" ]]; then
        inconsistence_ids+=("$alink_record_cnt")
        #echo "Mismatch detected: alink_record_cnt=$alink_record_cnt, id=$id"
    fi

    if [[ "${block[2]}" == *"No MSPOSD.msg available"* ]]; then
        return
    fi
    

    ###################################
    # Extract timestamp               #
    ###################################
    timestamp_line="${block[1]}"

    timestamp=$(extract_timestamp "$timestamp_line")
    alink_time_stamp+=($timestamp)

    ###################################
    # Extract profile                 #
    ###################################
    profile_line="${block[2]}"

    time_elapsed=$(extract_profile_time_elapsed "$profile_line")
    alink_time_elapsed+=($time_elapsed)

    bitrate=$(extract_profile_bitrate "$profile_line")
    alink_bitrate+=($bitrate)
    check_tx_bitrate $bitrate

    bandwidth=$(extract_profile_bandwidth "$profile_line")
    alink_bandwidth+=($bandwidth)

    gi=$(extract_profile_gi "$profile_line")
    alink_gi+=($gi)

    mcs=$(extract_profile_mcs "$profile_line")
    alink_mcs+=($mcs)

    k=$(extract_profile_k "$profile_line")
    alink_k+=($k)

    n=$(extract_profile_n "$profile_line")
    alink_n+=($n)

    pwr=$(extract_profile_pwr "$profile_line")
    alink_pwr+=($pwr)
    check_tx_power $pwr

    gop=$(extract_profile_gop "$profile_line")
    alink_gop+=($gop)

    ###################################
    # Extract OSD                     #
    ###################################
    osd_line="${block[3]}"

    osd_bitrate=$(extract_regular_osd_bitrate "$osd_line")
    alink_osd_bitrate+=($osd_bitrate)

    osd_fps=$(extract_regular_osd_fps "$osd_line")
    alink_osd_fps+=($osd_fps)

    osd_cpu=$(extract_regular_osd_cpu "$osd_line")
    alink_osd_cpu+=($osd_cpu)
    check_cpu $osd_cpu

    osd_cpu_temp=$(extract_regular_osd_cpu_temp "$osd_line")
    alink_osd_cpu_temp+=($osd_cpu_temp)
    check_cpu_temp $osd_cpu_temp   

    osd_tx_temp=$(extract_regular_osd_tx_temp "$osd_line")
    alink_osd_tx_temp+=($osd_tx_temp)
    check_tx_temp $osd_tx_temp

    ###################################
    # Extract Q/RSSI/SNR value        #
    ###################################
    score_line="${block[4]}"

    linkq_value=$(extract_linkq "$score_line")
    alink_linkq+=($linkq_value)

    smthdq_value=$(extract_smthdq "$score_line")
    alink_smthdq+=($smthdq_value)

    rssi_snr_line="${block[5]}"

    rssi_value=$(extract_rssi_value "$rssi_snr_line")
    alink_rssi_value+=($rssi_value)

    snr_value=$(extract_snr_value "$rssi_snr_line")
    alink_snr_value+=($snr_value)

    extra_fec=$(extract_extra_fec "$rssi_snr_line")
    alink_extra_rx_fec+=($extra_fec)

    extra_rx_lost=$(extract_extra_rx_lost "$rssi_snr_line")
    alink_extra_rx_lost+=($extra_rx_lost)

    check_link_score $rssi_value $snr_value $linkq_value $smthdq_value

    ###################################
    # Extract Extra info              #
    ###################################
    extra_line="${block[6]}"

    extra_pnlt=$(extract_extra_pnlt "$extra_line")
    alink_extra_pnlt+=($extra_pnlt)

    extra_tx_dropped=$(extract_extra_tx_dropped "$extra_line")
    adjust_extra_tx_dropped "$extra_tx_dropped"
    alink_extra_tx_dropped+=($adjust_tx_dropped_result)

    extra_tx_requested=$(extract_extra_tx_requested "$extra_line")
    adjust_extra_tx_requested "$extra_tx_requested"
    alink_extra_tx_requested+=($adjust_tx_requested_result)

    extra_rx_requested=$(extract_extra_rx_requested "$extra_line")
    adjust_extra_rx_requested "$extra_rx_requested"
    alink_extra_rx_requested+=($adjust_rx_requested_result)

    check_link_status $extra_rx_lost $extra_fec $extra_pnlt $adjust_tx_dropped_result $adjust_tx_requested_result $adjust_rx_requested_result
}

# Function to process the file
process_file() {
    local input_file="$1"
    local total_lines=$(wc -l < "$input_file")  # Get total lines of input file
    local current_line=0
    local block=()  # Store multi-line block
    local processing_block=false  # Track if we're in a block

    while IFS= read -r line || [[ -n "$line" ]]; do
        ((current_line++))

        # Update progress bar
        echo -ne "Processing: $(progress_bar $current_line $total_lines 20 '=')\r" >&2

        # Detect start of a new record (numbered lines)
        if [[ "$line" =~ ^[0-9]+$ ]]; then
            if [[ $processing_block == true ]]; then
                process_block
                block=()  # Reset block
            fi
            processing_block=true  # Mark new record start
        fi

        # Store lines in block
        block+=("$line")
    done < "$input_file"

    # Process the last block if it exists
    if [[ ${#block[@]} -gt 0 ]]; then
        process_block
    fi
}

# Process the file and exit
process_file $srt_file

######################################################################
# Functions for debug
######################################################################

# DEBUG
#print_table alink_time_stamp $column

#print_table alink_time_elapsed $column
#print_table alink_bitrate $column
#print_table alink_bandwidth $column
#print_table alink_gi $column
#print_table alink_mcs $column
#print_table alink_k $column
#print_table alink_n $column
#print_table alink_pwr $column
#print_table alink_gop $column

#print_table alink_osd_bitrate $column
#print_table alink_osd_fps $column
#print_table alink_osd_cpu $column
#print_table alink_osd_tx_temp $column

#print_table alink_linkq $column
#print_table alink_smthdq $column

#print_table alink_rssi_value $column
#print_table alink_rssi_score $column

#print_table alink_snr_value $column
#print_table alink_snr_score $column

#print_table alink_extra_rx_fec $column
#print_table alink_extra_pnlt $column
#print_table alink_extra_tx_dropped $column
#print_table alink_extra_tx_requested $column
#print_table alink_extra_rx_requested $column

######################################################################
# Summary
######################################################################
echo "" # for progress bar

#
# SRT file consistency check
#

echo ""
if [[ ${#inconsistence_ids[@]} -eq 0 ]]; then
    echo "alink srt file is consistent!"
else
    echo "alink srt file is inconsistent!"
    echo "number of elements in inconsistence_ids: ${#inconsistence_ids[@]}"
    print_table inconsistence_ids $column
fi

#
# export data to CSV format file
#

export_to_csv > $csv_file
echo -e "$csv_file auto-generated!"

#
# report statistics
#

report_cpu
report_tx
report_link_score

#
# specialized analysis
#

report_link_status

exit 0

