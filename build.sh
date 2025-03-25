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
cp ../gki.xml .repo/manifests/
yes | repo init -m gki.xml --depth=1

# Sync repo
repo sync -c --no-clone-bundle --no-tags -j$(($(nproc) * 2))

# Setup KernelSU
curl -LSs "https://raw.githubusercontent.com/tiann/KernelSU/main/kernel/setup.sh" | bash -

# Setup compiler wrapper
rm prebuilts/clang/host/linux-x86/clang-r487747c/bin/clang.real
cp ../gki-wrapper.py prebuilts/clang/host/linux-x86/clang-r487747c/bin/clang.real

# Apply patches
patch -p1 < ../disable_mitigations.patch

# Setup custom defconfig
# tools/bazel run //common:kernel_aarch64_config -- menuconfig
cp ../gki_defconfig common/arch/arm64/configs/gki_defconfig

# Build kernel images
tools/bazel run --config=release --lto=full //common:kernel_aarch64_dist
