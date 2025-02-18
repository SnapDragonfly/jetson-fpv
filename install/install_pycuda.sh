#!/bin/bash

source ../scripts/common/dir.sh
source ../scripts/common/url.sh

install_dependencies () {
    sudo apt-get install universal-ctags libboost-python-dev -y
    pip install pytools==2023.1
}

git_source () {
    local version="$1"    # First parameter: pycuda version
    local ssh_key="/home/$2/.ssh/id_rsa"  # Second parameter: Path to the SSH private key
    local protocol="${3:-https}"  # Third parameter: Protocol type (default is https)

    echo "Getting version '$version' of pycuda using protocol '$protocol'"

    if [ "$protocol" = "ssh" ]; then
        # Use SSH protocol and specify the private key
        GIT_SSH_COMMAND="ssh -i $ssh_key" git clone git@github.com:inducer/pycuda.git
    else
        # Use HTTPS protocol (default)
        git clone "$version" https://github.com/inducer/pycuda.git
    fi

    cd pycuda
    git checkout tags/$version
    git submodule init
    git submodule update
}

main () {
    # Get the user running the script (before sudo)
    original_user=${SUDO_USER:-$(whoami)}
    echo "Original user before sudo: $original_user"
    current_path=$(pwd)

    setup
    install_dependencies   
    git_source "v2024.1.2" ${original_user} "ssh"

    python configure.py --cuda-root=/usr/local/cuda/targets/aarch64-linux
    export PATH=${PATH}:/usr/local/cuda/bin
    export LD_LIBRARY_PATH=${LD_LIBRARY_PATH}:/usr/local/cuda/lib64
    export CPATH=$CPATH:/usr/local/cuda/targets/aarch64-linux/include
    export LIBRARY_PATH=$LIBRARY_PATH:/usr/local/cuda/targets/aarch64-linux/lib
    export PATH=/usr/local/cuda/bin:$PATH
    export CUDA_INC_DIR=/usr/local/cuda/include
    sudo make install
}

main "$@"