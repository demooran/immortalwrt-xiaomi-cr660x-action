#!/usr/bin/env bash
# File name: diy-part1.sh
# Description: OpenWrt DIY script part 1 (Before Update feeds)
# Target: OpenWrt 23.05 - Xiaomi CR6609

set -e

# إزالة أي نسخة سابقة لثيم Argon لضمان سحب نظيف عند إعادة البناء
rm -rf package/luci-theme-argon

# سحب ثيم Argon المحدّث والمتوافق مع OpenWrt 23.05
git clone --depth 1 https://github.com/jerrykuku/luci-theme-argon.git package/luci-theme-argon
