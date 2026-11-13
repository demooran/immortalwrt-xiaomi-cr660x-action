#!/bin/bash
#
# Copyright (c) 2019-2020 P3TERX <https://p3terx.com>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#
# https://github.com/P3TERX/Actions-OpenWrt
# File name: diy-part2.sh
# Description: OpenWrt DIY script part 2 (After Update feeds)
#

# ==========================================
# 1. تعيين اسم الجهاز (Hostname)
# ==========================================
sed -i 's/OpenWrt/PROMAX/g' package/base-files/files/bin/config_generate
sed -i 's/ImmortalWrt/PROMAX/g' package/base-files/files/bin/config_generate

# ==========================================
# 2. إعدادات الواي فاي الافتراضية (تفعيل الراديو)
# ==========================================
WIFI_FILE="package/kernel/mac80211/files/lib/wifi/mac80211.sh"
if [ -f "$WIFI_FILE" ]; then
    sed -i 's/disabled=1/disabled=0/g' "$WIFI_FILE"
fi

# ==========================================
# 3. إعدادات وضع الـ Access Point والدولة - بدون VLAN وبدون Gateway
# ==========================================
mkdir -p package/base-files/files/etc/uci-defaults
cat << 'EOF' > package/base-files/files/etc/uci-defaults/99-set-ap-mode
#!/bin/sh

# 1. حذف واجهات الـ WAN تماماً وإبقاء LAN فقط
uci delete network.wan 2>/dev/null || true
uci delete network.wan6 2>/dev/null || true

# 2. تعطيل خدمة DHCP على واجهة LAN (لأن الميكروتك هو من سيوفر العناوين)
uci set dhcp.lan.ignore=1
uci set dhcp.lan.dynamicdhcp=0

# 3. تعطيل خدمات IPv6
uci set dhcp.lan.ra=disabled
uci set dhcp.lan.dhcpv6=disabled
uci set dhcp.lan.ndp=disabled

# 4. تعيين عنوان IP ثابت للجهاز (بدون Gateway)
uci set network.lan.proto=static
uci set network.lan.ipaddr=192.168.1.21
uci set network.lan.netmask=255.255.255.0
uci delete network.lan.gateway 2>/dev/null || true

# 5. إعدادات الواي فاي (عزل العملاء وإلغاء الفصل التلقائي)
uci set wireless.default_radio0.isolate=1
uci set wireless.default_radio0.disassoc_low_ack=0
if uci get wireless.default_radio1 >/dev/null 2>&1; then
    uci set wireless.default_radio1.isolate=1
    uci set wireless.default_radio1.disassoc_low_ack=0
fi

# 6. تعيين اسم الشبكة (SSID) وكلمة المرور (بدون كلمة مرور)
uci set wireless.default_radio0.ssid=promax
uci set wireless.default_radio0.encryption=none

if uci get wireless.default_radio1 >/dev/null 2>&1; then
    uci set wireless.default_radio1.ssid=promax_5G
    uci set wireless.default_radio1.encryption=none
fi

# حفظ التغييرات
uci commit dhcp
uci commit network
uci commit wireless
exit 0
EOF
chmod +x package/base-files/files/etc/uci-defaults/99-set-ap-mode

# ==========================================
# 4. تعطيل الخدمات غير الضرورية (مع إبقاء SSH يعمل) وتفعيل ثيم Argon
# ==========================================
cat << 'EOF' > package/base-files/files/etc/uci-defaults/98-disable-router-services
#!/bin/sh
/etc/init.d/firewall disable 2>/dev/null || true
/etc/init.d/eoip disable 2>/dev/null || true
/etc/init.d/mwan3 disable 2>/dev/null || true
/etc/init.d/odhcpd disable 2>/dev/null || true
/etc/init.d/log disable 2>/dev/null || true
/etc/init.d/dnsmasq disable 2>/dev/null || true

# تعيين ثيم Argon كافتراضي للنظام تلقائياً
uci set luci.main.mediaurlbase='/luci-static/argon'
uci commit luci

exit 0
EOF
chmod +x package/base-files/files/etc/uci-defaults/98-disable-router-services

# ==========================================
# 5. إخفاء خيارات SSH والـ Keys بشكل جذري من واجهة LuCI
# ==========================================
rm -f feeds/luci/modules/luci-mod-system/luasrc/controller/admin/keys.lua 2>/dev/null || true
find . -name "keys.lua" -exec rm -f {} \; 2>/dev/null || true

if [ -f "feeds/luci/collections/luci/Makefile" ]; then
    sed -i 's/luci-theme-bootstrap/luci-theme-argon/g' feeds/luci/collections/luci/Makefile 2>/dev/null || true
fi

# ==========================================
# 6. تفعيل الواي فاي الإجباري وضبط قوة الإرسال (30 dBm)
# ==========================================
cat << 'EOF' > package/base-files/files/etc/uci-defaults/99-fix-wifi-power
#!/bin/sh
uci set wireless.radio0.disabled=0
uci set wireless.radio1.disabled=0
uci set wireless.radio0.txpower=30
uci set wireless.radio1.txpower=30
uci delete wireless.radio0.country 2>/dev/null || true
uci delete wireless.radio1.country 2>/dev/null || true
uci commit wireless
wifi reload
exit 0
EOF
chmod +x package/base-files/files/etc/uci-defaults/99-fix-wifi-power
