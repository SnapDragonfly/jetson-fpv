#!/bin/bash

source ../scripts/common/dir.sh

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


    sudo apt-get install deepstream-7.1 -y
    sudo chown daniel:daniel /opt/nvidia/deepstream/deepstream-7.1 -R

    #DEEPSTREAM_URL="https://api.ngc.nvidia.com/v2/resources/org/nvidia/deepstream/7.1/files?redirect=true&path=deepstream_sdk_v7.1.0_jetson.tbz2"
    #DEEPSTREAM_INSTALL=deepstream_sdk_v7.1.0_jetson.tbz2
    #echo "Downloading $DEEPSTREAM_INSTALL ..."
    #wget --tries=10 --retry-connrefused --waitretry=5 --timeout=30 -O $DEEPSTREAM_INSTALL $DEEPSTREAM_URL

    #sudo tar -xvf $DEEPSTREAM_INSTALL -C /
    #cd /opt/nvidia/deepstream/deepstream-7.1
    #sudo ./install.sh
    #sudo ldconfig
    #cd -

    PYDS_URL=https://github.com/NVIDIA-AI-IOT/deepstream_python_apps/releases/download/v1.2.0/pyds-1.2.0-cp310-cp310-linux_aarch64.whl
    PYDS_INSTALL=pyds-1.2.0-cp310-cp310-linux_aarch64.whl
    wget --tries=10 --retry-connrefused --waitretry=5 --timeout=30 -O $PYDS_INSTALL $PYDS_URL
    python3 -m pip install --no-cache $PYDS_INSTALL
    pip3 install cuda-python

    cd $current_path/../utils/deepstream/
    rm -f samples
    ln -sf /opt/nvidia/deepstream/deepstream/samples/ samples

    cd $current_path
}

main "$@"


