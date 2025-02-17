#!/bin/bash

source ../scripts/common/dir.sh
source ../scripts/common/url.sh

install_dependencies () {
    sudo apt-get install -y dkms
}

git_source () {
    local ssh_key="/home/$1/.ssh/id_rsa"  # Second parameter: Path to the SSH private key
    local protocol="${2:-https}"  # Third parameter: Protocol type (default is https)

    if [ "$protocol" = "ssh" ]; then
        # Use SSH protocol and specify the private key
        GIT_SSH_COMMAND="ssh -i $ssh_key" git clone git@github.com:svpcom/rtl8812au.git
   else
        # Use HTTPS protocol (default)
        git clone https://github.com:svpcom/rtl8812au.git
    fi
}

build () {
    cd rtl8812au
    sudo ./dkms-install.sh
    make
    sudo make install
    sudo modprobe 88XXau_wfb
}

main () {
    # Get the user running the script (before sudo)
    original_user=${SUDO_USER:-$(whoami)}
    echo "Original user before sudo: $original_user"
    current_path=$(pwd)

    setup
    install_dependencies
    git_source  ${original_user} ${GIT_PROTOCOL} 

    build
}

main "$@"