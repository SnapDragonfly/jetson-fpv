#!/bin/bash

source ./scripts/common/progress.sh

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
  echo "Verbose mode enabled, with $column columns detailed distributed numbers."
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

# Check if the file has the .srt extension, if so, replace it with .csv
if [[ "$srt_file" == *.srt ]]; then
    csv_file="${base_name}.csv"
else
    # If no extension is present, add .csv
    csv_file="${srt_file}.csv"
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
# Functions: print_table
# $1 -> array for print
# $2 -> columns for print
######################################################################
print_table() {
    local array_name="$1"
    local columns="${2:-10}"  # Default to 10 columns if not specified
    local -n arr_ref="$array_name"  # Use nameref to reference the array dynamically
    local count=0      # Counter for printing new lines
    local width=10     # Minimum width for each column

    # Print header
    echo "Printing table: $array_name"
    echo "------------------------------------------"

    # Iterate through the array and print each value
    for value in "${arr_ref[@]}"; do
        # Print the value with specified width and a space
        printf "%-${width}s " "$value"
        ((count++))

        # Print a new line after every 'columns' values
        if ((count % columns == 0)); then
            printf "\n"  # Ensure line break
        fi
    done

    # Ensure a final newline if the last row is incomplete
    if ((count % columns != 0)); then
        printf "\n"  # Add final newline if the last row didn't finish
    fi
}

######################################################################
# Functions for data extract
######################################################################

alink_record_cnt=0

# Function to extract timestamp and milliseconds
alink_time_stamp=()
extract_timestamp() {
    # Input format: 00:00:00,000 --> 00:00:00,309

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

    local profile_line="$1"

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

    local profile_line="$1"

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

    local profile_line="$1"

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

    local profile_line="$1"

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

    local profile_line="$1"

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

    local profile_line="$1"

    # Extract the fourth field: "10/15"
    local kn_field=$(echo "$profile_line" | awk '{print $4}')

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

    local profile_line="$1"

    # Extract the fourth field: "10/15"
    local kn_field=$(echo "$profile_line" | awk '{print $4}')

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

    local profile_line="$1"

    # Extract the fifth field: "Pw50"
    local pwr_field=$(echo "$profile_line" | awk '{print $5}')

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

    local profile_line="$1"

    # Extract the sixth field: "g10.0"
    local gop_field=$(echo "$profile_line" | awk '{print $6}')

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

    local osd_string="$1"  # Input string, e.g., "2.0Mb FPS:60 CPU59% tx44c"

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

    local osd_string="$1"  # Input string, e.g., "2.0Mb FPS:60 CPU59% tx44c"

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

    local osd_string="$1"  # Input string, e.g., "2.0Mb FPS:60 CPU59% tx44c"

    # Use sed to extract the number after 'CPU' and discard the '%' symbol
    local cpu=$(echo "$osd_string" | sed -n 's/.*CPU\([0-9]*\)%.*$/\1/p')

    # Output the extracted CPU value (e.g., 59)
    echo "$cpu"
}

# Function to extract OSD TX temperature
alink_osd_tx_temp=()
extract_regular_osd_tx_temp() {
    # char global_regular_osd[64] = "&L%d0&F%d&B &C tx&Wc";
    # 2.0Mb FPS:60 CPU59% tx44c

    local osd_string="$1"  # Input string, e.g., "2.0Mb FPS:60 CPU59% tx44c"

    # Use sed to extract the number after 'tx' and discard the 'c' character
    local tx_temp=$(echo "$osd_string" | sed -n 's/.*tx\([0-9]*\)c.*$/\1/p')

    # Output the extracted temperature value (e.g., 44)
    echo "$tx_temp"
}

# Function to extract orignal score of link quality
alink_original_score=()
extract_score_original() {
    # sprintf(global_score_related_osd, "og %d, smthd %d", osd_raw_score, osd_smoothed_score);
    # og 1711, smthd 1698

    local osd_string="$1"  # Input string, e.g., "og 1711, smthd 1698"

    # Use sed to extract the number after 'og' and discard the rest
    local og_score=$(echo "$osd_string" | sed -n 's/.*og \([0-9]*\),.*/\1/p')

    # Output the extracted score value (e.g., 1711)
    echo "$og_score"
}

# Function to extract filtered score of link quality
alink_filtered_score=()
extract_score_filtered() {
    # sprintf(global_score_related_osd, "og %d, smthd %d", osd_raw_score, osd_smoothed_score);
    # og 1711, smthd 1698

    local osd_string="$1"  # Input string, e.g., "og 1711, smthd 1698"

    # Use sed to extract the number after 'smthd' and discard the rest
    local smthd_score=$(echo "$osd_string" | sed -n 's/.*smthd \([0-9]*\)/\1/p')

    # Output the extracted score value (e.g., 1698)
    echo "$smthd_score"
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

    local osd_string="$1"  # Input string, e.g., "rssi-32, 1960"

    # Use sed to extract the number after 'rssi' and discard the rest
    local rssi_value=$(echo "$osd_string" | sed -n 's/.*rssi\([-0-9]*\),.*/\1/p')

    # Output the extracted RSSI value (e.g., -32)
    echo "$rssi_value"
}

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

    local osd_string="$1"  # Input string, e.g., "rssi-32, 1960"

    # Use sed to extract the number after the comma (,) and discard the rest
    local rssi_score=$(echo "$osd_string" | sed -n 's/.*rssi[-0-9]*,\s*\([0-9]*\).*/\1/p')

    # Output the extracted score value (e.g., 1960)
    echo "$rssi_score"
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

    local osd_string="$1"  # Input string, e.g., "snr24, 1462"

    # Use sed to extract the number after 'snr' and discard the rest
    local snr_value=$(echo "$osd_string" | sed -n 's/.*snr\([0-9]*\),.*/\1/p')

    # Output the extracted SNR value (e.g., 24)
    echo "$snr_value"
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

    local osd_string="$1"  # Input string, e.g., "snr24, 1462"

    # Use sed to extract the number after the comma (,) and discard the rest
    local snr_score=$(echo "$osd_string" | sed -n 's/.*snr[-0-9]*,\s*\([0-9]*\).*/\1/p')

    # Output the extracted score value (e.g., 1462)
    echo "$snr_score"
}

# Function to extract extra info: fec
alink_extra_fec=()
extract_extra_fec() {
    # sprintf(global_gs_stats_osd, "rssi%d, %d\nsnr%d, %d\nfec%d", 
    # rssi1, link_value_rssi, snr1, link_value_snr, recovered);
    # snprintf(global_extra_stats_osd, sizeof(global_extra_stats_osd), "pnlt%d xtx%ld(%d) idr%d",
    # applied_penalty, global_total_tx_dropped, total_keyframe_requests_xtx, total_keyframe_requests);
    # rssi-32, 1960 \n 
    # snr24, 1462 \n 
    # fec4 pnlt0 xtx0(0) idr0

    local osd_string="$1"  # Input string, e.g., "fec4 pnlt0 xtx0(0) idr0"

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

    local osd_string="$1"  # Input string, e.g., "fec4 pnlt0 xtx0(0) idr0"

    # Use sed to extract the number after 'pnlt' and discard the rest
    local pnlt_value=$(echo "$osd_string" | sed -n 's/.*pnlt\([0-9]*\).*/\1/p')

    # Output the extracted PNLT value (e.g., 0)
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

    local osd_string="$1"  # Input string, e.g., "fec4 pnlt0 xtx35(0) idr0"

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

    local osd_string="$1"  # Input string, e.g., "fec4 pnlt0 xtx0(0) idr0"

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

# Function to extract extra info: keyframe_requested
alink_extra_keyframe_requested=()
extract_extra_keyframe_requested() {
    # sprintf(global_gs_stats_osd, "rssi%d, %d\nsnr%d, %d\nfec%d", 
    # rssi1, link_value_rssi, snr1, link_value_snr, recovered);
    # snprintf(global_extra_stats_osd, sizeof(global_extra_stats_osd), "pnlt%d xtx%ld(%d) idr%d",
    # applied_penalty, global_total_tx_dropped, total_keyframe_requests_xtx, total_keyframe_requests);
    # rssi-32, 1960 \n 
    # snr24, 1462 \n 
    # fec4 pnlt0 xtx0(0) idr0

    local osd_string="$1"  # Input string, e.g., "fec4 pnlt0 xtx0(0) idr0"

    # Use sed to extract the number after 'idr' and discard the rest
    local keyframe_requested_value=$(echo "$osd_string" | sed -n 's/.*idr\([0-9]*\).*/\1/p')

    # Output the extracted value (e.g., 0)
    echo "$keyframe_requested_value"
}

declare -g alink_latest_keyframe_requested=-1
declare -g adjust_keyframe_requested_result
adjust_extra_keyframe_requested() {
    local keyframe_requested_value="$1"

    if [[ -z "$keyframe_requested_value" ]]; then
        adjust_keyframe_requested_result=0
        return
    fi

    if [[ $alink_latest_keyframe_requested -eq -1 ]]; then
        alink_latest_keyframe_requested=$keyframe_requested_value
        adjust_keyframe_requested_result=0
    else
        local delta_requested_value=$((keyframe_requested_value - alink_latest_keyframe_requested))
        alink_latest_keyframe_requested=$keyframe_requested_value
        adjust_keyframe_requested_result=$delta_requested_value
    fi
}

export_to_csv() {
    # Define the headers (remove 'alink_' prefix and set as column names)
    local headers="time, elapsed, bitrate, bandwidth, gi, mcs, k, n, pwr, gop, osd_bitrate, fps, cpu, tx_temp, og_score, ft_score, rssi_value, rssi_score, snr_value, snr_score, fec, pnlt, tx_dropped, tx_requested, keyframe_requested"

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
        echo -n "${alink_osd_tx_temp[i]},"
        echo -n "${alink_original_score[i]},"
        echo -n "${alink_filtered_score[i]},"
        echo -n "${alink_rssi_value[i]},"
        echo -n "${alink_rssi_score[i]},"
        echo -n "${alink_snr_value[i]},"
        echo -n "${alink_snr_score[i]},"
        echo -n "${alink_extra_fec[i]},"
        echo -n "${alink_extra_pnlt[i]},"
        echo -n "${alink_extra_tx_dropped[i]},"
        echo -n "${alink_extra_tx_requested[i]},"
        echo "${alink_extra_keyframe_requested[i]}"
    done

    # Print a newline to end the row
    echo
}

######################################################################
# Functions for data analysis
######################################################################

# Function: Check and update RSSI values
alink_rssi_value_min=9999
alink_rssi_value_max=-999
alink_rssi_score_min=9999
alink_rssi_score_max=0
check_rssi() {
    local value=$1
    local score=$2

    if [[ -n "$value" ]]; then
        # Update the minimum/maximum RSSI value
        if [[ $value -lt $alink_rssi_value_min ]]; then
            alink_rssi_value_min=$value
        fi
        if [[ $value -gt $alink_rssi_value_max ]]; then
            alink_rssi_value_max=$value
        fi
    fi

    if [[ -n "$score" ]]; then
        # Update the minimum/maximum RSSI score
        if [[ $score -lt $alink_rssi_score_min ]]; then
            alink_rssi_score_min=$score
        fi
        if [[ $score -gt $alink_rssi_score_max ]]; then
            alink_rssi_score_max=$score
        fi
    fi
}

# Function: Print RSSI statistics
report_rssi() {
    echo ""
    echo "------------------------------------------"
    echo "RSSI value: $alink_rssi_value_min ~ $alink_rssi_value_max"
    echo "RSSI score: $alink_rssi_score_min ~ $alink_rssi_score_max"
}

# Function: Check and update SNR values
alink_snr_value_min=9999
alink_snr_value_max=0
alink_snr_score_min=9999
alink_snr_score_max=0
check_snr() {
    local value=$1
    local score=$2

    if [[ -n "$value" ]]; then
        # Update the minimum/maximum SNR value
        if [[ $value -lt $alink_snr_value_min ]]; then
            alink_snr_value_min=$value
        fi
        if [[ $value -gt $alink_snr_value_max ]]; then
            alink_snr_value_max=$value
        fi
    fi

    if [[ -n "$score" ]]; then
        # Update the minimum/maximum SNR score
        if [[ $score -lt $alink_snr_score_min ]]; then
            alink_snr_score_min=$score
        fi
        if [[ $score -gt $alink_snr_score_max ]]; then
            alink_snr_score_max=$score
        fi
    fi
}

# Function: Print SNR statistics
report_snr() {
    echo ""
    echo "------------------------------------------"
    echo "SNR value: $alink_snr_value_min ~ $alink_snr_value_max"
    echo "SNR score: $alink_snr_score_min ~ $alink_snr_score_max"
}

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

# Function: Print CPU statistics
report_cpu() {
    echo ""
    echo "------------------------------------------"
    echo "CPU usage: $alink_cpu_min% ~ $alink_cpu_max%"

    # Check if the maximum CPU usage exceeds threshold
    if [[ $alink_cpu_max -gt 70 ]]; then
        echo "!WARNING!: CPU usage exceeded 70%!"
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

# Function: Print TX temperature statistics
report_tx_temp() {
    echo ""
    echo "------------------------------------------"
    echo "TX Celsius: $alink_tx_temp_min ~ $alink_tx_temp_max"

    # Check if the maximum TX temperature exceeds threshold
    if [[ $alink_tx_temp_max -gt 100 ]]; then
        echo "!WARNING!: TX temperature exceeded 100 degree Celsius"
    fi
}

# Function: Check and update original/filtered link scores
alink_og_score_min=9999
alink_og_score_max=-999
alink_smthd_score_min=9999
alink_smthd_score_max=0
check_link_score() {
    local og_score=$1
    local smthd_score=$2

    if [[ -n "$og_score" ]]; then
        # Update the minimum/maximum original score
        if [[ $og_score -lt $alink_og_score_min ]]; then
            alink_og_score_min=$og_score
        fi
        if [[ $og_score -gt $alink_rssi_value_max ]]; then
            alink_rssi_value_max=$og_score
        fi
    fi

    if [[ -n "$smthd_score" ]]; then
        # Update the minimum/maximum filtered score
        if [[ $smthd_score -lt $alink_smthd_score_min ]]; then
            alink_smthd_score_min=$smthd_score
        fi
        if [[ $smthd_score -gt $alink_smthd_score_max ]]; then
            alink_smthd_score_max=$smthd_score
        fi
    fi
}

# Function: Print link score statistics
report_link_score() {
    echo ""
    echo "------------------------------------------"
    echo "original score: $alink_og_score_min ~ $alink_og_score_max"
    echo "filtered score: $alink_smthd_score_min ~ $alink_smthd_score_max"

    if [[ $verbose -eq 1 ]]; then
        print_table alink_filtered_score $column
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

# Function: Print TX power statistics
report_tx_power() {
    echo ""
    echo "------------------------------------------"
    echo "TX Power: $alink_tx_power_min ~ $alink_tx_power_max"
    #print_table alink_pwr $column
}

# Function: Check and update bitrate
alink_tx_bitrate_min=9999
alink_tx_bitrate_max=0
check_tx_bitrate() {
    local value=$1

    if [[ -z "$value" ]]; then
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

# Function: Print TX bitrate statistics
report_tx_bitrate() {
    echo ""
    echo "------------------------------------------"
    echo "TX bitrate(kbps): $alink_tx_bitrate_min ~ $alink_tx_bitrate_max"
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

    osd_tx_temp=$(extract_regular_osd_tx_temp "$osd_line")
    alink_osd_tx_temp+=($osd_tx_temp)
    check_tx_temp $osd_tx_temp

    ###################################
    # Extract scores                  #
    ###################################
    score_line="${block[4]}"

    original_score=$(extract_score_original "$score_line")
    alink_original_score+=($original_score)

    filtered_score=$(extract_score_filtered "$score_line")
    alink_filtered_score+=($filtered_score)

    check_link_score $original_score $filtered_score

    ###################################
    # Extract RSSI                    #
    ###################################
    rssi_line="${block[5]}"

    rssi_value=$(extract_rssi_value "$rssi_line")
    alink_rssi_value+=($rssi_value)

    rssi_score=$(extract_rssi_score "$rssi_line")
    alink_rssi_score+=($rssi_score)

    check_rssi $rssi_value $rssi_score

    ###################################
    # Extract SNR                     #
    ###################################
    snr_line="${block[6]}"

    snr_value=$(extract_snr_value "$snr_line")
    alink_snr_value+=($snr_value)

    snr_score=$(extract_snr_score "$snr_line")
    alink_snr_score+=($snr_score)

    check_snr $snr_value $snr_score

    ###################################
    # Extract Extra info              #
    ###################################
    extra_line="${block[7]}"

    extra_fec=$(extract_extra_fec "$extra_line")
    alink_extra_fec+=($extra_fec)

    extra_pnlt=$(extract_extra_pnlt "$extra_line")
    alink_extra_pnlt+=($extra_pnlt)

    extra_tx_dropped=$(extract_extra_tx_dropped "$extra_line")
    adjust_extra_tx_dropped "$extra_tx_dropped"
    alink_extra_tx_dropped+=($adjust_tx_dropped_result)

    extra_tx_requested=$(extract_extra_tx_requested "$extra_line")
    adjust_extra_tx_requested "$extra_tx_requested"
    alink_extra_tx_requested+=($adjust_tx_requested_result)

    extra_keyframe_requested=$(extract_extra_keyframe_requested "$extra_line")
    adjust_extra_keyframe_requested "$extra_keyframe_requested"
    alink_extra_keyframe_requested+=($adjust_keyframe_requested_result)
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

#print_table alink_original_score $column
#print_table alink_filtered_score $column

#print_table alink_rssi_value $column
#print_table alink_rssi_score $column

#print_table alink_snr_value $column
#print_table alink_snr_score $column

#print_table alink_extra_fec $column
#print_table alink_extra_pnlt $column
#print_table alink_extra_tx_dropped $column
#print_table alink_extra_tx_requested $column
#print_table alink_extra_keyframe_requested $column

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
report_tx_temp
report_tx_power
report_tx_bitrate
report_rssi
report_snr

#
# specialized analysis
#

report_link_score

exit 0

