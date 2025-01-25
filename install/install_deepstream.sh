#!/bin/bash

cleanup () {
# https://stackoverflow.com/questions/226703/how-do-i-prompt-for-yes-no-cancel-input-in-a-linux-shell-script
    while true ; do
        echo "Do you wish to remove temporary build files in /tmp/build_deepstream ? "
        if ! [[ "$1" -eq "--test-warning" ]] ; then
            echo "(Doing so may make running tests on the build later impossible)"
        fi
        read -p "Y/N " yn
        case ${yn} in
            [Yy]* ) rm -rf /tmp/build_deepstream ; break;;
            [Nn]* ) exit ;;
            * ) echo "Please answer yes or no." ;;
        esac
    done
}

setup () {
    cd /tmp
    if [[ -d "build_deepstream" ]] ; then
        echo "It appears an existing build exists in /tmp/build_deepstream"
        cleanup
    fi
    mkdir -p build_deepstream
    cd build_deepstream
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

    DEEPSTREAM_URL="https://api.ngc.nvidia.com/v2/resources/org/nvidia/deepstream/7.1/files?redirect=true&path=deepstream_sdk_v7.1.0_jetson.tbz2"
    DEEPSTREAM_INSTALL=deepstream_sdk_v7.1.0_jetson.tbz2
    echo "Downloading $DEEPSTREAM_INSTALL ..."
    wget --tries=10 --retry-connrefused --waitretry=5 --timeout=30 -O $DEEPSTREAM_INSTALL $DEEPSTREAM_URL

    sudo tar -xvf $DEEPSTREAM_INSTALL -C /
    cd /opt/nvidia/deepstream/deepstream-7.1
    sudo ./install.sh
    sudo ldconfig

    cd -

    PYDS_URL=https://github.com/NVIDIA-AI-IOT/deepstream_python_apps/releases/download/v1.2.0/pyds-1.2.0-cp310-cp310-linux_aarch64.whl
    PYDS_INSTALL=pyds-1.2.0-cp310-cp310-linux_aarch64.whl
    wget --tries=10 --retry-connrefused --waitretry=5 --timeout=30 -O $PYDS_INSTALL $PYDS_URL
    python3 -m pip install --no-cache $PYDS_INSTALL

    cd $current_path/../utils/deepstream/
    rm -f samples
    ln -sf /opt/nvidia/deepstream/deepstream/samples/ samples

    cd $current_path
    cleanup --test-warning
}

main "$@"


