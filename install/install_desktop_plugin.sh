#!/bin/bash

source ../scripts/common/dir.sh
source ../scripts/common/url.sh

install_dependencies () {
    sudo apt-get install gnome-shell-extension-manager -y
}

main () {
    # Get the user running the script (before sudo)
    original_user=${SUDO_USER:-$(whoami)}
    echo "Original user before sudo: $original_user"
    current_path=$(pwd)

    setup
    install_dependencies   

    # Just Perfection for Download
    JUST_PERFECTION_INSTALL=just-perfection-desktopjust-perfection.v26.shell-extension.zip
    JUST_PERFECTION_URL="${PLUGIN_URL}${JUST_PERFECTION_INSTALL}"

    echo "Downloading $JUST_PERFECTION_INSTALL ..."
    
    mkdir -p just-perfection-desktop@just-perfection
    cd just-perfection-desktop@just-perfection
    wget --tries=10 --retry-connrefused --waitretry=5 --timeout=30 -O $JUST_PERFECTION_INSTALL $JUST_PERFECTION_URL
    unzip just-perfection-desktopjust-perfection.v26.shell-extension.zip
    cd ..
    mv just-perfection-desktop@just-perfection ~/.local/share/gnome-shell/extensions/

    # Pixel Saver for Download
    PIXEL_SAVER_INSTALL=pixel-saverdeadalnix.me.v29.shell-extension.zip
    PIXEL_SAVER_URL="${PLUGIN_URL}${PIXEL_SAVER_INSTALL}"

    echo "Downloading $PIXEL_SAVER_INSTALL ..."
    mkdir -p pixel-saverdeadalnix.me
    mv pixel-saverdeadalnix.me.v29.shell-extension.zip pixel-saverdeadalnix.me
    cd pixel-saverdeadalnix.me/
    wget --tries=10 --retry-connrefused --waitretry=5 --timeout=30 -O $PIXEL_SAVER_INSTALL $PIXEL_SAVER_URL
    unzip pixel-saverdeadalnix.me.v29.shell-extension.zip
    cd ..
    mv pixel-saverdeadalnix.me/ pixel-saver@deadalnix.me
    mv pixel-saver@deadalnix.me/ ~/.local/share/gnome-shell/extensions/

    gnome-shell --replace &
    cd $current_path
}

main "$@"