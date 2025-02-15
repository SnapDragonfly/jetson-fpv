

# Function to get the DeepStream C/C++ SDK version
get_deepstream_version() {
    local version_file="/opt/nvidia/deepstream/deepstream/version"
    
    # Check if the version file exists
    if [[ -f "$version_file" ]]; then
        # Extract the version number from the file
        local version=$(cat "$version_file" | grep -oP '(?<=Version: ).*')
        echo "$version"
    else
        echo "NULL.Unknow"
    fi
}