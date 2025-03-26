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

# Setup custom toolchain
sed -i -e 's/r450784e/r510928/' common/build.config.constants
rm prebuilts/clang/host/linux-x86/clang-r510928/bin/clang.real
cp ../gki-wrapper.py prebuilts/clang/host/linux-x86/clang-r510928/bin/clang.real

# Setup custom defconfig
# BUILD_CONFIG=common/build.config.gki.aarch64 build/config.sh
cp ../gki_defconfig common/arch/arm64/configs/gki_defconfig
rm common/android/gki_aarch64_modules
touch common/android/gki_aarch64_modules

# Strip missing ABI symbols
grep -F -v -f ../strip_symbols common/android/abi_gki_aarch64 > stripped_abi && mv stripped_abi common/android/abi_gki_aarch64
for file in common/android/abi_gki_aarch64_*; do
    echo "Stripping ABI symbols: $file"
    grep -F -v -f ../strip_symbols $file > stripped_abi && mv stripped_abi $file
done

# Build kernel images
LTO=full BUILD_CONFIG=common/build.config.gki.aarch64 build/build.sh
