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

