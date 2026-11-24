#!/usr/bin/env bash
# File name: diy-part1.sh
# Description: OpenWrt DIY script part 1 (Before Update feeds)
# Target: OpenWrt 23.05 - Xiaomi CR6609 / MT7621

# 1. إزالة أي نسخة قديمة أو متعارضة لثيم Argon أو بقايا feed argon2305
rm -rf package/luci-theme-argon \
       package/luci-app-argon-config \
       feeds/luci/themes/luci-theme-argon \
       feeds/argon2305 \
       package/base-files/files/www/luci-static/resources/menu-argon.js \
       files/www/luci-static/resources/menu-argon.js

sed -i '/argon2305/d' feeds.conf.default 2>/dev/null || true

# 2. جلب luci-theme-argon مباشرة إلى package/luci-theme-argon (متوافق مع OpenWrt 23.05)
git clone --depth 1 https://github.com/jerrykuku/luci-theme-argon.git package/luci-theme-argon
