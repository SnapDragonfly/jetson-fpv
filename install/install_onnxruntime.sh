#!/bin/bash

source ../scripts/common/dir.sh
source ../scripts/common/url.sh

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

    #ONNXRUNTIME_URL=https://github.com/SnapDragonfly/onnxruntime/releases/download/jetson_orin_l4t_36.4_v1.19.2/onnxruntime_gpu-1.19.2-cp310-cp310-linux_aarch64.whl
    #ONNXRUNTIME_INSTALL=onnxruntime_gpu-1.19.2-cp310-cp310-linux_aarch64.whl
    ONNXRUNTIME_INSTALL=onnxruntime_gpu-1.20.0-cp310-cp310-linux_aarch64.whl
    ONNXRUNTIME_URL="${REPO_URL}${ONNXRUNTIME_INSTALL}"
    echo "Downloading $ONNXRUNTIME_INSTALL ..."
    wget --tries=10 --retry-connrefused --waitretry=5 --timeout=30 -O $ONNXRUNTIME_INSTALL $ONNXRUNTIME_URL
    python3 -m pip install --no-cache $ONNXRUNTIME_INSTALL

    cd $current_path
}

main "$@"