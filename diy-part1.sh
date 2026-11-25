# Download Argon Theme v2.3.1
echo "Downloading Argon Theme..."

rm -rf package/luci-theme-argon

git clone --depth 1 --branch v2.2.8 \
https://github.com/jerrykuku/luci-theme-argon.git \
package/luci-theme-argon

if [ ! -f package/luci-theme-argon/Makefile ]; then
    echo "ERROR: Argon download failed!"
    exit 1
fi

echo "Argon downloaded successfully!"
