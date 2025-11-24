#!/usr/bin/bash -e
REPO_DIR="$(dirname "$(realpath "$0")")"

# Setup repo
if [ ! -f /usr/local/bin/repo ]; then
    wget -O /usr/local/bin/repo https://storage.googleapis.com/git-repo-downloads/repo
    chmod +x /usr/local/bin/repo
    git config --global user.email "40174982+HeXis-YS@users.noreply.github.com"
    git config --global user.name "HeXis-YS"
fi

mkdir gki
pushd gki

# Download compiler first
mkdir -p prebuilts/clang/host/linux-x86/clang-r450784e
pushd prebuilts/clang/host/linux-x86/clang-r450784e
wget -qO- https://android.googlesource.com/platform/prebuilts/clang/host/linux-x86/+archive/ebcc6c3bef363bc539ea39f45b6abae1dce6ff1a/clang-r574158.tar.gz | tar -xzf- &
popd

# Setup GKI manifests
yes | repo init -u https://android.googlesource.com/kernel/manifest --depth=1
cp $REPO_DIR/gki.xml .repo/manifests/
yes | repo init -m gki.xml --depth=1

# Sync repo
repo sync -c --no-tags --no-clone-bundle -j8

pushd common

# Pretend version
sed -i 's/^SUBLEVEL = .*/SUBLEVEL = 170/' Makefile
echo "-android13-8-g52ccd9134339" > .scmversion

# Set default zstd level to 1
sed -i 's/^#define ZSTD_DEF_LEVEL.*/#define ZSTD_DEF_LEVEL 1/' crypto/zstd.c

# Lock CPU freq
patch -p1 -N <<'EOF'
diff --git a/include/linux/cpufreq.h b/include/linux/cpufreq.h
index 4b4fbf4cf..860d7da07 100644
--- a/include/linux/cpufreq.h
+++ b/include/linux/cpufreq.h
@@ -464,8 +464,8 @@ static inline void cpufreq_verify_within_limits(struct cpufreq_policy_data *poli
 static inline void
 cpufreq_verify_within_cpu_limits(struct cpufreq_policy_data *policy)
 {
-	cpufreq_verify_within_limits(policy, policy->cpuinfo.min_freq,
-				     policy->cpuinfo.max_freq);
+	policy->min = policy->cpuinfo.min_freq;
+	policy->max = policy->cpuinfo.max_freq;
 }
 
 #ifdef CONFIG_CPU_FREQ
EOF

# Setup custom defconfig
cp $REPO_DIR/gki_defconfig arch/arm64/configs/gki_defconfig
truncate -s 0 android/gki_aarch64_modules

popd # common

# Setup KernelSU
curl -LSs "https://raw.githubusercontent.com/tiann/KernelSU/main/kernel/setup.sh" | bash -

# Setup Re:Kernel
$REPO_DIR/rekernel.sh

# Waiting for the compiler download to complete
wait

# Setup compiler wrapper
pushd prebuilts/clang/host/linux-x86/clang-r450784e/bin
mv clang-real clang-real_
install -m 755 $REPO_DIR/gki-wrapper.py clang-real
popd

# Build kernel images
# BUILD_CONFIG=common/build.config.gki.aarch64 build/config.sh
LTO=full BUILD_CONFIG=common/build.config.gki.aarch64 build/build.sh

cp out/android13-5.15/dist/boot.img $REPO_DIR/

# Repack system_dlkm.img
export PATH=$(realpath prebuilts/kernel-build-tools/linux-x86/bin):$PATH
pushd out/android13-5.15/staging/system_dlkm_staging
cp -r $REPO_DIR/etc ./
touch etc/fs_config_dirs etc/fs_config_files
popd # out/android13-5.15/staging/system_dlkm_staging
popd # gki

build_image gki/out/android13-5.15/staging/system_dlkm_staging system_dlkm_props_file system_dlkm.img /dev/null
avbtool add_hashtree_footer --partition_name system_dlkm --hash_algorithm sha256 --image system_dlkm.img
