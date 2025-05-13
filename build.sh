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
repo sync -c --no-clone-bundle -j9
popd
mv /tmp/gki gki
pushd gki

# Disable dirty label
sed -i -e 's/ -dirty//' common/scripts/setlocalversion

# Setup KernelSU
curl -LSs "https://raw.githubusercontent.com/tiann/KernelSU/main/kernel/setup.sh" | bash -

# Setup compiler wrapper
REAL_COMPILER=$(basename $(readlink prebuilts/clang/host/linux-x86/current/bin/clang.real))
rm prebuilts/clang/host/linux-x86/current/bin/clang.real
sed -e "s/@REAL_COMPILER@/$REAL_COMPILER/" ../gki-wrapper.py > prebuilts/clang/host/linux-x86/current/bin/clang.real
chmod 755 prebuilts/clang/host/linux-x86/current/bin/clang.real

# Setup custom defconfig
# BUILD_CONFIG=common/build.config.gki.aarch64 build/config.sh
cp ../gki_defconfig common/arch/arm64/configs/gki_defconfig
truncate -s 0 common/android/gki_aarch64_modules

# Build kernel images
LTO=full BUILD_CONFIG=common/build.config.gki.aarch64 build/build.sh
popd

cp gki/out/android13-5.15/dist/boot.img ./

# Repack system_dlkm.img
export PATH=$(realpath gki/prebuilts/kernel-build-tools/linux-x86/bin):$PATH
cp -r etc gki/out/android13-5.15/staging/system_dlkm_staging/
build_image gki/out/android13-5.15/staging/system_dlkm_staging system_dlkm_props_file system_dlkm.img /dev/null
avbtool add_hashtree_footer --partition_name system_dlkm --hash_algorithm sha256 --image system_dlkm.img
