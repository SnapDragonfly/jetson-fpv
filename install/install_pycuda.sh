#!/bin/bash

cleanup () {
# https://stackoverflow.com/questions/226703/how-do-i-prompt-for-yes-no-cancel-input-in-a-linux-shell-script
    while true ; do
        echo "Do you wish to remove temporary build files in /tmp/build_pycuda ? "
        if ! [[ "$1" -eq "--test-warning" ]] ; then
            echo "(Doing so may make running tests on the build later impossible)"
        fi
        read -p "Y/N " yn
        case ${yn} in
            [Yy]* ) rm -rf /tmp/build_pycuda ; break;;
            [Nn]* ) exit ;;
            * ) echo "Please answer yes or no." ;;
        esac
    done
}

setup () {
    cd /tmp
    if [[ -d "build_pycuda" ]] ; then
        echo "It appears an existing build exists in /tmp/build_pycuda"
        cleanup
    fi
    mkdir -p build_pycuda
    cd build_pycuda
}

install_dependencies () {
    sudo apt-get install universal-ctags
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

    cleanup --test-warning
}

main "$@"