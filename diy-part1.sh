#!/usr/bin/env bash
# File name: diy-part1.sh
# Description: OpenWrt DIY script part 1 (Before Update feeds)
# Target: OpenWrt 22.03 - Xiaomi CR6609 / MT7621

set -e

# إزالة أي نسخة سابقة لثيم Argon لضمان سحب نظيف عند إعادة البناء
rm -rf package/luci-theme-argon

# سحب ثيم Argon بفرع 18.06 المتوافق مع واجهة OpenWrt 22.03 (Lua)
git clone --depth 1 -b 18.06 https://github.com/jerrykuku/luci-theme-argon.git package/luci-theme-argon
