#!/usr/bin/bash
# Setup repo
wget -O /usr/local/bin/repo https://storage.googleapis.com/git-repo-downloads/repo
chmod a+x /usr/local/bin/repo
git config --global user.email "40174982+HeXis-YS@users.noreply.github.com"
git config --global user.name "HeXis-YS"

# Setup GKI manifests
mkdir gki
cd gki
yes | repo init -u https://android.googlesource.com/kernel/manifest --depth=1
cp ../kernel.xml .repo/manifests/
yes | repo init -m kernel.xml --depth=1

# Sync repo
repo sync -c --no-clone-bundle --no-tags -j$(($(nproc) * 2))

# Setup KernelSU
curl -LSs "https://raw.githubusercontent.com/tiann/KernelSU/main/kernel/setup.sh" | bash -

# Setup custom toolchain
sed -i -e 's/r450784e/r510928/' common/build.config.constants
rm prebuilts/clang/host/linux-x86/clang-r510928/bin/clang.real
cp ../gki-wrapper.py prebuilts/clang/host/linux-x86/clang-r510928/bin/clang.real

# Setup custom defconfig
cp ../gki_defconfig common/arch/arm64/configs/gki_defconfig
rm common/android/gki_aarch64_modules
touch common/android/gki_aarch64_modules

# Build kernel images
GKI_KERNEL_CMDLINE="mitigations=off" LTO=full BUILD_CONFIG=common/build.config.gki.aarch64 build/build.sh
