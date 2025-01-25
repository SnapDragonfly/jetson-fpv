#!/bin/bash

cleanup () {
# https://stackoverflow.com/questions/226703/how-do-i-prompt-for-yes-no-cancel-input-in-a-linux-shell-script
    while true ; do
        echo "Do you wish to remove temporary build files in /tmp/build_onnxruntime ? "
        if ! [[ "$1" -eq "--test-warning" ]] ; then
            echo "(Doing so may make running tests on the build later impossible)"
        fi
        read -p "Y/N " yn
        case ${yn} in
            [Yy]* ) rm -rf /tmp/build_onnxruntime ; break;;
            [Nn]* ) exit ;;
            * ) echo "Please answer yes or no." ;;
        esac
    done
}

setup () {
    cd /tmp
    if [[ -d "build_onnxruntime" ]] ; then
        echo "It appears an existing build exists in /tmp/build_onnxruntime"
        cleanup
    fi
    mkdir -p build_onnxruntime
    cd build_onnxruntime
}

install_dependencies () {
    echo ""
}

main () {
    # Get the user running the script (before sudo)
    original_user=${SUDO_USER:-$(whoami)}
    echo "Original user before sudo: $original_user"
    current_path=$(pwd)

    setup
    install_dependencies   

    ONNXRUNTIME_URL=https://github.com/SnapDragonfly/onnxruntime/releases/download/jetson_orin_l4t_36.4_v1.19.2/onnxruntime_gpu-1.19.2-cp310-cp310-linux_aarch64.whl
    ONNXRUNTIME_INSTALL=onnxruntime_gpu-1.19.2-cp310-cp310-linux_aarch64.whl
    echo "Downloading $ONNXRUNTIME_INSTALL ..."
    wget --tries=10 --retry-connrefused --waitretry=5 --timeout=30 -O $ONNXRUNTIME_INSTALL $ONNXRUNTIME_URL
    python3 -m pip install --no-cache $ONNXRUNTIME_INSTALL

    cd $current_path

    cleanup --test-warning
}

main "$@"