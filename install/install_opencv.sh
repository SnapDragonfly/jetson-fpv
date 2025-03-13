#!/bin/bash

source ../scripts/common/dir.sh
source ../scripts/common/url.sh

set -e

# change default constants here:
readonly PREFIX=/usr/local  # install prefix, (can be ~/.local for a user install)
readonly DEFAULT_VERSION=4.11.0  # controls the default version (gets reset by the first argument)
readonly CPUS=$(nproc)  # controls the number of jobs

#readonly GIT_PROTOCOL="ssh"
readonly GIT_PROTOCOL="https"
readonly ENABLE_PROXY="NO"

# better board detection. if it has 6 or more cpus, it probably has a ton of ram too
if [[ $CPUS -gt 5 ]]; then
    # something with a ton of ram
    JOBS=$CPUS
else
    JOBS=1  # you can set this to 4 if you have a swap file
    # otherwise a Nano will choke towards the end of the build
fi

git_source () {
    local version="$1"    # First parameter: OpenCV version
    local ssh_key="/home/$2/.ssh/id_rsa"  # Second parameter: Path to the SSH private key
    local protocol="${3:-https}"  # Third parameter: Protocol type (default is https)

    echo "Getting version '$version' of OpenCV using protocol '$protocol'"

    if [ "$protocol" = "ssh" ]; then
        # Use SSH protocol and specify the private key
        if [ ! -d "opencv" ]; then
            GIT_SSH_COMMAND="ssh -i $ssh_key" git clone --depth 1 --branch "$version" git@github.com:opencv/opencv.git
        else
            echo "Directory 'opencv' already exists, skipping clone."
        fi

        if [ ! -d "opencv_contrib" ]; then
            GIT_SSH_COMMAND="ssh -i $ssh_key" git clone --depth 1 --branch "$version" git@github.com:opencv/opencv_contrib.git
        else
            echo "Directory 'opencv_contrib' already exists, skipping clone."
        fi
    else
        # Use HTTPS protocol (default)
        if [ ! -d "opencv" ]; then
            git clone --depth 1 --branch "$version" https://github.com/opencv/opencv.git
        else
            echo "Directory 'opencv' already exists, skipping clone."
        fi

        if [ ! -d "opencv_contrib" ]; then
            git clone --depth 1 --branch "$version" https://github.com/opencv/opencv_contrib.git
        else
            echo "Directory 'opencv_contrib' already exists, skipping clone."
        fi
    fi
}

install_dependencies () {
    # open-cv has a lot of dependencies, but most can be found in the default
    # package repository or should already be installed (eg. CUDA).
    sudo apt-get install -y \
        build-essential \
        cmake \
        git \
        gfortran \
        libatlas-base-dev \
        libavcodec-dev \
        libavformat-dev \
        libcanberra-gtk3-module \
        libdc1394-dev \
        libeigen3-dev \
        libglew-dev \
        libgstreamer-plugins-base1.0-dev \
        libgstreamer-plugins-good1.0-dev \
        libgstreamer1.0-dev \
        libgtk-3-dev \
        libavif-dev \
        libopenjp2-7 \
        libopenjp2-7-dev \
        libjpeg-dev \
        libjpeg8-dev \
        liblcms2-dev \
        libjpeg-turbo8-dev \
        liblapack-dev \
        liblapacke-dev \
        libopenblas-dev \
        libpng-dev \
        libpostproc-dev \
        libswscale-dev \
        libtbb-dev \
        libtbb2 \
        libtesseract-dev \
        libtiff-dev \
        libv4l-dev \
        libxine2-dev \
        libxvidcore-dev \
        libx264-dev \
        pkg-config \
        python3-dev \
        python3-numpy \
        python3-matplotlib \
        qv4l2 \
        v4l-utils \
        zlib1g-dev \
        default-jdk \
        libvtk9-dev \
        libgflags-dev \
        libgoogle-glog-dev \
        libogre-1.9-dev \
        libhdf5-dev
}

configure () {
    if [ "$ENABLE_PROXY" = "YES" ]; then
        PROXY_FLAGS="$HTTP_PROXY $HTTPS_PROXY"
    else
        PROXY_FLAGS=""
    fi

    local CMAKEFLAGS="
        -D CMAKE_BUILD_TYPE=RELEASE
        -D OPENCV_EXTRA_MODULES_PATH=/tmp/build_jetson/opencv_contrib/modules
        -D BUILD_EXAMPLES=OFF
        -D BUILD_opencv_python3=ON
        -D PYTHON_EXECUTABLE=$(which python3)
        -D PYTHON3_INCLUDE_DIR=$(python3 -c "from distutils.sysconfig import get_python_inc; print(get_python_inc())")
        -D PYTHON3_LIBRARY=$(python3 -c "import sysconfig; print(sysconfig.get_config_var('LIBDIR'))")
        -D PYTHON3_PACKAGES_PATH=$(python3 -c "import site; print(site.getsitepackages()[0])")
        -D CMAKE_INSTALL_PREFIX=${PREFIX}
        -D CUDA_ARCH_BIN=8.7
        -D CUDA_ARCH_PTX=8.7
        -D CUDA_FAST_MATH=ON
        -D CUDNN_VERSION='9.3'
        -D EIGEN_INCLUDE_PATH=/usr/include/eigen3 
        -D OPENCV_DNN_CUDA=ON
        -D OPENCV_ENABLE_NONFREE=ON
        -D OPENCV_GENERATE_PKGCONFIG=ON
        -D WITH_CUBLAS=ON
        -D WITH_CUDA=ON
        -D WITH_CUDNN=ON
        -D WITH_NVCUVID=OFF
        -D WITH_NVCUVENC=OFF
        -D BUILD_opencv_wechat_qrcode=OFF
        -D BUILD_opencv_xfeatures2d=OFF
        -D WITH_GSTREAMER=ON
        -D WITH_LIBV4L=ON
        -D WITH_OPENGL=ON"

    if [[ "$1" != "test" ]] ; then
        CMAKEFLAGS="
        ${CMAKEFLAGS}
        -D BUILD_PERF_TESTS=OFF
        -D BUILD_TESTS=OFF"
    fi

    CMAKEFLAGS="${CMAKEFLAGS} ${PROXY_FLAGS}"

    echo "cmake flags: ${CMAKEFLAGS}"

    cd opencv
    mkdir -p build
    cd build
    cmake ${CMAKEFLAGS} .. 2>&1 | tee -a configure.log
}

main () {

    # Get the user running the script (before sudo)
    original_user=${SUDO_USER:-$(whoami)}
    echo "Original user before sudo: $original_user"

    local VER=${DEFAULT_VERSION}

    # parse arguments
    if [[ "$#" -gt 0 ]] ; then
        VER="$1"  # override the version
    fi

    if [[ "$#" -gt 1 ]] && [[ "$2" == "test" ]] ; then
        DO_TEST=1
    fi

    # prepare for the build:
    setup
    install_dependencies
    git_source ${VER} ${original_user} ${GIT_PROTOCOL}

    if [[ ${DO_TEST} ]] ; then
        configure test
    else
        configure
    fi

    # start the build
    make -j${JOBS} 2>&1 | tee -a build.log

    if [[ ${DO_TEST} ]] ; then
        make test 2>&1 | tee -a test.log
    fi

    # avoid a sudo make install (and root owned files in ~) if $PREFIX is writable
    if [[ -w ${PREFIX} ]] ; then
        make install 2>&1 | tee -a install.log
    else
        sudo make install 2>&1 | tee -a install.log
    fi
}

main "$@"
