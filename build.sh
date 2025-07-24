#!/usr/bin/bash
set -e

# Setup repo
if [ ! -f /usr/local/bin/repo ]; then
    wget -O /usr/local/bin/repo https://storage.googleapis.com/git-repo-downloads/repo
    chmod +x /usr/local/bin/repo
    git config --global user.email "40174982+HeXis-YS@users.noreply.github.com"
    git config --global user.name "HeXis-YS"
fi

# Setup GKI manifests
mkdir gki
pushd gki
yes | repo init -u https://android.googlesource.com/kernel/manifest --depth=1
cp ../gki.xml .repo/manifests/
yes | repo init -m gki.xml --depth=1

# Sync repo
repo sync -c --no-clone-bundle -j9

# Disable dirty label
sed -i -e 's/ -dirty//' common/scripts/setlocalversion

# Set default zstd level to 1
sed -i -e 's/#define ZSTD_DEF_LEVEL	3/#define ZSTD_DEF_LEVEL	1/g' common/crypto/zstd.c

# Setup custom defconfig
cp ../gki_defconfig common/arch/arm64/configs/gki_defconfig
truncate -s 0 common/android/gki_aarch64_modules
# BUILD_CONFIG=common/build.config.gki.aarch64 build/config.sh

# Setup KernelSU
curl -LSs "https://raw.githubusercontent.com/tiann/KernelSU/main/kernel/setup.sh" | bash -

# Setup compiler wrapper
pushd prebuilts/clang/host/linux-x86/clang-r450784e/bin
mv clang-real clang-real_
popd
install -m 755 ../gki-wrapper.py prebuilts/clang/host/linux-x86/clang-r450784e/bin/clang-real

# Build kernel images
LTO=full BUILD_CONFIG=common/build.config.gki.aarch64 build/build.sh
popd

cp gki/out/android13-5.15/dist/boot.img ./

# Repack system_dlkm.img
export PATH=$(realpath gki/prebuilts/kernel-build-tools/linux-x86/bin):$PATH
cp -r etc gki/out/android13-5.15/staging/system_dlkm_staging/
build_image gki/out/android13-5.15/staging/system_dlkm_staging system_dlkm_props_file system_dlkm.img /dev/null
avbtool add_hashtree_footer --partition_name system_dlkm --hash_algorithm sha256 --image system_dlkm.img
