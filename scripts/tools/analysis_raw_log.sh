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
dos2unix $input_file

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

inference_ids=()
inference_len=0
inference_max=0

deepsort_ids=()
deepsort_len=0
deepsort_max=0
perf_interval_min=9999
perf_interval_max=0

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
    elif [[ $line == *"FRAME: inference"* ]]; then
        # FRAME: inference 1273
        id=$(echo "$line" | awk '{print $3}')
        inference_ids+=($id)
        ((inference_len++))

        #echo "id=$id max=$inference_max"
        if [[ $id -gt $inference_max ]]; then
            inference_max=$id
        fi
    elif [[ $line == *"FRAME: deepsort"* ]]; then
        # FRAME: deepsort 1318 4
        id=$(echo "$line" | awk '{print $3}')
        interval=$(echo "$line" | awk '{print $4}')
        deepsort_ids+=($id)
        ((deepsort_len++))

        #echo "id=$id interval=$interval min=$perf_interval_min max=$perf_interval_max"
        if [[ $id -gt $deepsort_max ]]; then
            deepsort_max=$id
        fi

        if (( $(echo "$interval > $perf_interval_max" | bc -l) )); then
            perf_interval_max=$interval
        fi

        if (( $(echo "$interval < $perf_interval_min" | bc -l) )); then
            perf_interval_min=$interval
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

video_capture_consistency=true
video_capture_frame_lost=0
video_capture_missing_ids=()

video_forward_consistency=true
video_forward_frame_lost=0
video_forward_missing_ids=()
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

        video_forward_consistency=false
        ((video_forward_frame_lost++))
        video_forward_missing_ids+=($id)
        continue
    fi
    video_capture_consistency=false
    ((video_capture_frame_lost++))
    video_capture_missing_ids+=($id)
done

((percentage_capture_frame_lost=100*$video_capture_frame_lost/$overall_max))
((percentage_forward_frame_lost=100*$video_forward_frame_lost/$overall_max))

echo ""
echo "Video(totl): $overall_max frames"
if $video_capture_consistency; then
    echo "Video: frames capture are continuous"
else
    echo "Video: frames capture experience loss $video_capture_frame_lost frames - $percentage_capture_frame_lost%"
    echo "Video: specific missing ${video_capture_frame_lost} frame are ${video_capture_missing_ids[@]}"
fi
if $video_forward_consistency; then
    echo "Video: frames forward are continuous"
else
    echo "Video: frames forward experience loss $video_forward_frame_lost frames - $percentage_forward_frame_lost%"
    echo "Video: specific missing ${video_forward_frame_lost} frame are ${video_forward_missing_ids[@]}"
fi

################################################################################
# Stage 3: Inference frame consistency check                                   #
################################################################################

overall_max=$((inference_max > deepsort_max ? inference_max : deepsort_max))
current_deal=0
current_skip=0

inference_consistency=true
inference_frame_lost=0
inference_missing_ids=()

echo ""
echo "### Inference consistency check ..."
for (( id = 0; id < overall_max; id++ )); do
    echo -ne "Processing: $(progress_bar $((id+1)) $overall_max 20 '=')\r" >&2

    offset=($(find_id_in_array $id $current_deal $inference_len "${inference_ids[@]}"))
    if [[ $offset -ne -1 ]]; then
        current_deal=$offset
        continue
    fi
    offset=($(find_id_in_array $id $current_skip $deepsort_len "${deepsort_ids[@]}"))
    if [[ $offset -ne -1 ]]; then
        current_skip=$offset
        continue
    fi

    inference_consistency=false
    ((inference_frame_lost++))
    inference_missing_ids+=($id)
done

((percentage_inference=100*$inference_len/$overall_max))
((percentage_passthrough=100*$deepsort_len/$overall_max))
((percentage_lost=100*$inference_frame_lost/$overall_max))

echo ""
echo "Inference(totl): $overall_max frames"
echo "Inference(eval): $inference_len frames - $percentage_inference%"
echo "Inference(skip): $deepsort_len frames - $percentage_passthrough%"
echo "Inference(lost): $inference_frame_lost frames - $percentage_lost%"
echo "Inference(int_min): $perf_interval_min inference/p"
echo "Inference(int_max): $perf_interval_max inference/p"
echo "Inference(inf_min): $perf_inf_min second"
echo "Inference(inf_max): $perf_inf_max second"
echo "Inference(track_min): $perf_track_min second"
echo "Inference(track_max): $perf_track_max second"
if $inference_consistency; then
    echo "Inference: frames are continuous"
else
    echo "Inference: frames experience loss"
    echo "Inference: specific missing ${inference_frame_lost} frame are ${inference_missing_ids[@]}"
fi


