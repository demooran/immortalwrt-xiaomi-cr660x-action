#!/usr/bin/env bash
# File name: diy-part1.sh
# Description: OpenWrt DIY script part 1 (Before Update feeds)
# Target: OpenWrt 22.03 - Xiaomi CR6609 / MT7621

# إزالة أي نسخة سابقة لثيم Argon أو إضافاته قبل تحديث/تثبيت الـ feeds
rm -rf package/luci-theme-argon package/luci-app-argon-config feeds/luci/themes/luci-theme-argon
