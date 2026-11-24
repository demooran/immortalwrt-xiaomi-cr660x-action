#!/usr/bin/env bash
# File name: diy-part1.sh
# Description: OpenWrt DIY script part 1 (Before Update feeds)
# Target: OpenWrt 23.05 - Xiaomi CR6609 / MT7621

# 1. إزالة أي نسخة قديمة أو متعارضة لثيم Argon قبل تحديث الـ feeds
rm -rf package/luci-theme-argon \
       package/luci-app-argon-config \
       feeds/luci/themes/luci-theme-argon \
       package/base-files/files/www/luci-static/resources/menu-argon.js \
       files/www/luci-static/resources/menu-argon.js

# 2. إضافة مستودع luci-theme-argon المتوافق مع OpenWrt 23.05 (فرع 23.05)
if ! grep -q "jerrykuku/luci-theme-argon" feeds.conf.default 2>/dev/null; then
    echo "src-git argon2305 https://github.com/jerrykuku/luci-theme-argon.git;23.05" >> feeds.conf.default
fi
