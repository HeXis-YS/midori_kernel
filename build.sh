#!/usr/bin/bash
# Setup repo
wget -O /usr/local/bin/repo https://storage.googleapis.com/git-repo-downloads/repo
chmod a+x /usr/local/bin/repo
git config --global user.email "40174982+HeXis-YS@users.noreply.github.com"
git config --global user.name "HeXis-YS"

# Setup GKI manifests
mkdir gki
pushd gki
yes | repo init -u https://android.googlesource.com/kernel/manifest --depth=1
cp ../gki.xml .repo/manifests/
yes | repo init -m gki.xml --depth=1
popd

# Sync repo
rm -rf /tmp/gki
mv gki /tmp/gki
pushd /tmp/gki
repo sync -c --no-clone-bundle --no-tags -j$(($(nproc) * 2))
popd
mv /tmp/gki gki
pushd gki

# Setup KernelSU
curl -LSs "https://raw.githubusercontent.com/tiann/KernelSU/main/kernel/setup.sh" | bash -

# Setup custom toolchain
sed -i -e 's/r450784e/r510928/' common/build.config.constants
rm prebuilts/clang/host/linux-x86/clang-r510928/bin/clang.real
cp ../gki-wrapper.py prebuilts/clang/host/linux-x86/clang-r510928/bin/clang.real

# Setup custom defconfig
# BUILD_CONFIG=common/build.config.gki.aarch64 build/config.sh
cp ../gki_defconfig common/arch/arm64/configs/gki_defconfig
truncate -s 0 common/android/gki_aarch64_modules

# Build kernel images
LTO=full BUILD_CONFIG=common/build.config.gki.aarch64 build/build.sh
popd
