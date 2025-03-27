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