#!/bin/bash

# Check if the input file is provided
if [ -z "$1" ]; then
    echo "Usage: $0 <input_file>"
    exit 1
fi

input_file="$1"

# Verify that the input file exists
if [ ! -f "$input_file" ]; then
    echo "Error: File '$input_file' not found."
    exit 1
fi

# Unix format log
#dos2unix $input_file

# Print only the lines starting with "FRAME:" to the screen
#grep '^FRAME:' "$input_file"

find_id_in_array() {
    local id="$1"
    local start="$2"
    local length="$3"
    shift 3
    local id_array=("$@")

    if (( start >= length )); then
        echo -1
        return
    fi

    for (( i = start; i < length; i++ )); do
        if [[ "${id_array[i]}" == "$id" ]]; then
            echo ${i}
            return
        fi
    done

    echo -1
}

# Progress bar function
# Parameters:
#   $1: Current progress (0~total)
#   $2: Total count
#   $3: (Optional) Progress bar length, default is 50
#   $4: (Optional) Progress bar character, default is "█"
#   $5: (Optional) Show percentage, default is true
progress_bar() {
    local current=$1
    local total=$2
    local bar_len=${3:-50}          # Default length is 50
    local bar_char=${4:-"█"}        # Default fill character is █
    local show_percent=${5:-true}   # Default is to show percentage

    # Calculate progress
    ((percent = current * 100 / total))
    ((progress = percent * bar_len / 100))
    
    # Build progress bar
    local bar
    bar=$(printf "%${progress}s" "" | tr ' ' "$bar_char")
    printf "[%-${bar_len}s]" "$bar"  # Display the progress bar

    # Add percentage
    if [[ $show_percent == true ]]; then
        printf " %3d%%" "$percent"   # Align percentage to three digits
    fi
}

# Initialize the array and variables
put_ids=()
put_len=0
put_max=0

overflow_ids=()
overflow_len=0
overflow_max=0
overflow_packets_max=0

deal_ids=()
deal_len=0
deal_max=0

skip_ids=()
skip_len=0
skip_max=0
skip_packets_max=0

perf_inf_min=9999
perf_inf_max=0
perf_track_min=9999
perf_track_max=0
################################################################################
# Stage 1: Initialization                                                      #
################################################################################

# Read input file line by line
total_lines=$(wc -l < "$input_file")  # 获取文件总行数
current_line=0
echo ""
echo "### Video log reading ..."
while read -r line; do
    ((current_line++))
    echo -ne "Processing: $(progress_bar $((current_line)) $total_lines 20 '=')\r" >&2
    if [[ $line == *"FRAME: put"* ]]; then
        # FRAME: put 1315
        id=$(echo "$line" | awk '{print $3}')
        put_ids+=($id)
        ((put_len++))

        #echo "id=$id max=$put_max"
        if [[ $id -gt $put_max ]]; then
            put_max=$id
        fi
    elif [[ $line == *"FRAME: overflow"* ]]; then
        # FRAME: overflow 24 14
        id=$(echo "$line" | awk '{print $3}')
        packets=$(echo "$line" | awk '{print $4}')
        overflow_ids+=($id)
        ((overflow_len++))

        #echo "id=$id packets=$packets max=$overflow_max skip_max=$overflow_packets_max"
        if [[ $id -gt $overflow_max ]]; then
            overflow_max=$id
        fi
        if [[ $packets -gt $overflow_packets_max ]]; then
            overflow_packets_max=$packets
        fi
    elif [[ $line == *"FRAME: deal"* ]]; then
        # FRAME: deal 1273
        id=$(echo "$line" | awk '{print $3}')
        deal_ids+=($id)
        ((deal_len++))

        #echo "id=$id max=$deal_max"
        if [[ $id -gt $deal_max ]]; then
            deal_max=$id
        fi
    elif [[ $line == *"FRAME: skip"* ]]; then
        # FRAME: skip 1318 4
        id=$(echo "$line" | awk '{print $3}')
        packets=$(echo "$line" | awk '{print $4}')
        skip_ids+=($id)
        ((skip_len++))

        #echo "id=$id packets=$packets max=$skip_max skip_max=$skip_packets_max"
        if [[ $id -gt $skip_max ]]; then
            skip_max=$id
        fi
        if [[ $packets -gt $skip_packets_max ]]; then
            skip_packets_max=$packets
        fi
    elif [[ $line == *"FRAME: inf_min"* ]]; then
        #FRAME: inf_min 0.024784088134765625
        perf_inf_min=$(echo "$line" | awk '{print $3}')
    elif [[ $line == *"FRAME: inf_max"* ]]; then
        #FRAME: inf_max 0.4693596363067627
        perf_inf_max=$(echo "$line" | awk '{print $3}')
    elif [[ $line == *"FRAME: track_min"* ]]; then
        #FRAME: track_min 0.0013833045959472656
        perf_track_min=$(echo "$line" | awk '{print $3}')
    elif [[ $line == *"FRAME: track_max"* ]]; then
        #FRAME: track_max 0.015048027038574219
        perf_track_max=$(echo "$line" | awk '{print $3}')
    fi
done < "$input_file"
echo ""

################################################################################
# Stage 2: Video frame consistency check                                       #
################################################################################

overall_max=$((put_max > overflow_max ? put_max : overflow_max))
current_put=0
current_overflow=0
video_consistency=true
video_frame_lost=0
video_missing_ids=()
echo ""
echo "### Video frame consistency check ..."
for (( id = 0; id < overall_max; id++ )); do
    echo -ne "Processing: $(progress_bar $((id+1)) $overall_max 20 '=')\r" >&2

    offset=($(find_id_in_array $id $current_put $put_len "${put_ids[@]}"))
    if [[ $offset -ne -1 ]]; then
        current_put=$offset
        continue
    fi
    offset=($(find_id_in_array $id $current_overflow $overflow_len "${overflow_ids[@]}"))
    if [[ $offset -ne -1 ]]; then
        current_overflow=$offset
        continue
    fi
    video_consistency=false
    ((video_frame_lost++))
    video_missing_ids+=($id)
done

echo ""
echo "Video(totl): $overall_max frames"
echo "Video(lost): $video_frame_lost frames"
if $video_consistency; then
    echo "Video: frames are continuous"
else
    echo "Video: frames experience loss"
    echo "Video: specific missing frame are ${video_missing_ids[@]}"
fi

################################################################################
# Stage 3: Inference frame consistency check                                   #
################################################################################

overall_max=$((deal_max > skip_max ? deal_max : skip_max))
current_deal=0
current_skip=0

inference_consistency=true
inference_frame_lost=0
inference_missing_ids=()

echo ""
echo "### Inference consistency check ..."
for (( id = 0; id < overall_max; id++ )); do
    echo -ne "Processing: $(progress_bar $((id+1)) $overall_max 20 '=')\r" >&2

    offset=($(find_id_in_array $id $current_deal $deal_len "${deal_ids[@]}"))
    if [[ $offset -ne -1 ]]; then
        current_deal=$offset
        continue
    fi
    offset=($(find_id_in_array $id $current_skip $skip_len "${skip_ids[@]}"))
    if [[ $offset -ne -1 ]]; then
        current_skip=$offset
        continue
    fi

    inference_consistency=false
    ((inference_frame_lost++))
    inference_missing_ids+=($id)
done

((percentage_inference=100*$deal_len/$overall_max))
((percentage_passthrough=100*$skip_len/$overall_max))
((percentage_lost=100*$inference_frame_lost/$overall_max))

echo ""
echo "Inference(totl): $overall_max frames"
echo "Inference(eval): $deal_len frames - $percentage_inference%"
echo "Inference(skip): $skip_len frames - $percentage_passthrough%"
echo "Inference(lost): $inference_frame_lost frames - $percentage_lost%"
echo "Inference(inf_min): $perf_inf_min ms"
echo "Inference(inf_max): $perf_inf_max ms"
echo "Inference(track_min): $perf_track_min ms"
echo "Inference(track_max): $perf_track_max ms"
if $inference_consistency; then
    echo "Inference: frames are continuous"
else
    echo "Inference: frames experience loss"
    echo "Inference: specific missing frame are ${inference_missing_ids[@]}"
fi


