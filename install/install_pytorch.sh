#!/bin/bash

cleanup () {
# https://stackoverflow.com/questions/226703/how-do-i-prompt-for-yes-no-cancel-input-in-a-linux-shell-script
    while true ; do
        echo "Do you wish to remove temporary build files in /tmp/build_torch ? "
        if ! [[ "$1" -eq "--test-warning" ]] ; then
            echo "(Doing so may make running tests on the build later impossible)"
        fi
        read -p "Y/N " yn
        case ${yn} in
            [Yy]* ) rm -rf /tmp/build_torch ; break;;
            [Nn]* ) exit ;;
            * ) echo "Please answer yes or no." ;;
        esac
    done
}

setup () {
    cd /tmp
    if [[ -d "build_torch" ]] ; then
        echo "It appears an existing build exists in /tmp/build_torch"
        cleanup
    fi
    mkdir -p build_torch
    cd build_torch
}

install_dependencies () {
    sudo apt-get install -y libopenblas-dev curl
    pip3 install matplotlib numpy==1.23.5
}

main () {
    # Get the user running the script (before sudo)
    original_user=${SUDO_USER:-$(whoami)}
    echo "Original user before sudo: $original_user"
    current_path=$(pwd)

    setup
    install_dependencies

    # https://developer.nvidia.com/cusparselt-downloads?target_os=Linux&target_arch=aarch64-jetson&Compilation=Native&Distribution=Ubuntu&target_version=22.04&target_type=deb_local
    CUSPARSELT_URL=https://developer.download.nvidia.com/compute/cusparselt/0.6.3/local_installers/cusparselt-local-tegra-repo-ubuntu2204-0.6.3_1.0-1_arm64.deb
    CUSPARSELT_INSTALL=cusparselt-local-tegra-repo-ubuntu2204-0.6.3_1.0-1_arm64.deb
    wget $CUSPARSELT_URL
    sudo dpkg -i $cusparselt-local-tegra-repo-ubuntu2204-0.6.3_1.0-1_arm64.deb
    sudo cp /var/cusparselt-local-tegra-repo-ubuntu2204-0.6.3/cusparselt-local-tegra-E2326244-keyring.gpg /usr/share/keyrings/
    sudo apt-get update
    sudo apt-get -y install libcusparselt0 libcusparselt-dev

    TORCH_URL=https://github.com/SnapDragonfly/pytorch/releases/download/v2.5.1%2Bl4t35.6-cp38-cp38-aarch64/torch-2.5.1+l4t36.4-cp310-cp310-linux_aarch64.whl
    TORCH_INSTALL=torch-2.5.1+l4t36.4-cp310-cp310-linux_aarch64.whl
    echo "Downloading $TORCH_INSTALL ..."
    wget --tries=10 --retry-connrefused --waitretry=5 --timeout=30 -O $TORCH_INSTALL $TORCH_URL
    sudo python3 -m pip install --no-cache $TORCH_INSTALL

    git clone https://github.com/SnapDragonfly/vision.git torchvision
    cd torchvision
    git checkout nvidia_v0.20.0
    export BUILD_VERSION=0.20.0
    sudo python3 setup.py install --user

    cd $current_path

    cleanup --test-warning
}

main "$@"




