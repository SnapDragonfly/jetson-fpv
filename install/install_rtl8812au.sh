#!/bin/bash

cleanup () {
# https://stackoverflow.com/questions/226703/how-do-i-prompt-for-yes-no-cancel-input-in-a-linux-shell-script
    while true ; do
        echo "Do you wish to remove temporary build files in /tmp/build_rtl8812au ? "
        if ! [[ "$1" -eq "--test-warning" ]] ; then
            echo "(Doing so may make running tests on the build later impossible)"
        fi
        read -p "Y/N " yn
        case ${yn} in
            [Yy]* ) rm -rf /tmp/build_rtl8812au ; break;;
            [Nn]* ) exit ;;
            * ) echo "Please answer yes or no." ;;
        esac
    done
}

setup () {
    cd /tmp
    if [[ -d "build_rtl8812au" ]] ; then
        echo "It appears an existing build exists in /tmp/build_rtl8812au"
        cleanup
    fi
    mkdir -p build_rtl8812au
    cd build_rtl8812au
}

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
    git_source  ${original_user} "ssh"   

    build
    cleanup --test-warning
}

main "$@"