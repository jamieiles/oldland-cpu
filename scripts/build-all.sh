#!/bin/bash

set -ex

BUILD_DIR=$(pwd)/BUILD

mkdir -p ${BUILD_DIR}/binutils
pushd ${BUILD_DIR}/binutils
../../binutils-oldland/configure --prefix=${BUILD_DIR} --target=oldland-elf
make all -j8
make install
popd

mkdir -p ${BUILD_DIR}/sim
pushd ${BUILD_DIR}/sim
cmake -DCMAKE_INSTALL_PREFIX:PATH=${BUILD_DIR} ../../sim
make all -j8
make install
popd
