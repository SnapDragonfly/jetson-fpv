
cleanup () {
    # https://stackoverflow.com/questions/226703/how-do-i-prompt-for-yes-no-cancel-input-in-a-linux-shell-script
    local yn="$1"

    # If the first argument is "--test-warning", ignore it and shift the next argument
    if [[ "$yn" == "--test-warning" ]]; then
        echo "(Doing so may make running tests on the build later impossible)"
        shift  # Remove the first argument so that "$1" becomes the actual Y/N input
        yn="$1"
    fi

    # If the argument is provided but not Y/N, default to Y
    if [[ -n "$yn" && ! "$yn" =~ ^[YyNn]$ ]]; then
        yn="Y"
    fi

    while true; do
        echo "Do you wish to remove temporary build files in /tmp/build_jetson?"

        # If no argument is provided, prompt the user for input
        if [[ -z "$yn" ]]; then
            read -p "Y/N " yn
        fi

        case "$yn" in
            [Yy]* ) rm -rf /tmp/build_jetson; break ;; # Remove build files and exit loop
            [Nn]* ) exit ;; # Exit without deleting
            * ) echo "Please answer Y or N."; yn="";; # Clear yn for re-prompting
        esac
    done
}

setup () {
    if [[ -d "/tmp/build_jetson" ]] ; then
        echo "It appears an existing build exists in /tmp/build_jetson"
    else
        mkdir -p /tmp/build_jetson
    fi
    cd /tmp/build_jetson
}