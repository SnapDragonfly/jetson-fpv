#!/bin/bash
###############################################################################
# SPDX-FileCopyrightText: Copyright (c) 2021-2023 NVIDIA CORPORATION & AFFILIATES. All rights reserved.
# SPDX-License-Identifier: LicenseRef-NvidiaProprietary
#
# NVIDIA CORPORATION, its affiliates and licensors retain all intellectual
# property and proprietary rights in and to this material, related
# documentation and any modifications thereto. Any use, reproduction,
# disclosure or distribution of this material and related documentation
# without an express license agreement from NVIDIA CORPORATION or
# its affiliates is strictly prohibited.
###############################################################################

set -e

TRITON_DOWNLOADS=/tmp/triton_server_downloads
TRITON_PKG_PATH=${TRITON_PKG_PATH:=https://github.com/triton-inference-server/server/releases/download/v2.30.0/tritonserver2.30.0-jetpack5.1.tgz}
TRITON_BACKEND_DIR=/opt/nvidia/deepstream/deepstream/lib/triton_backends
DEEPSTREAM_LIB_DIR=/opt/nvidia/deepstream/deepstream/lib
TRITON_SERVER_BIN=/opt/tritonserver/bin

echo "Installing Triton prerequisites ..."
if [ $EUID -ne 0 ]; then
    echo "Must be run as root or sudo"
    exit 1
fi

apt-get update && \
    apt-get install -y --no-install-recommends libb64-dev libre2-dev libopenblas-dev

echo "Creating ${TRITON_DOWNLOADS} directory ..."
mkdir -p $TRITON_DOWNLOADS

echo "Downloading ${TRITON_PKG_PATH} to ${TRITON_DOWNLOADS} ... "
wget -O $TRITON_DOWNLOADS/jetpack.tgz $TRITON_PKG_PATH

echo "Creating ${TRITON_BACKEND_DIR} directory ... "
mkdir -p ${TRITON_BACKEND_DIR}

echo "Creating ${TRITON_SERVER_BIN} directory ... "
mkdir -p ${TRITON_SERVER_BIN}

echo "Extracting the Triton library and backend binaries ..."

tar -xzf $TRITON_DOWNLOADS/jetpack.tgz -C $DEEPSTREAM_LIB_DIR --strip-components=2 ./lib/libtritonserver.so
tar -xzf $TRITON_DOWNLOADS/jetpack.tgz -C $TRITON_BACKEND_DIR --wildcards --strip-components=2 ./backends/*
tar -xzf $TRITON_DOWNLOADS/jetpack.tgz -C $TRITON_SERVER_BIN --strip-components=2 ./bin/tritonserver

ldconfig
echo "cleaning up ${TRITON_DOWNLOADS} directory ..."
rm -rf $TRITON_DOWNLOADS
