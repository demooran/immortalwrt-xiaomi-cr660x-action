#!/usr/bin/env bash
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
# 3. إعدادات وضع الـ Access Point والدولة
# ==========================================
mkdir -p package/base-files/files/etc/uci-defaults
cat << 'EOF' > package/base-files/files/etc/uci-defaults/99-set-ap-mode
#!/bin/sh

# 1. حذف واجهات الـ WAN
uci delete network.wan 2>/dev/null || true
uci delete network.wan6 2>/dev/null || true

# 2. تعطيل DHCP على LAN
uci set dhcp.lan.ignore=1
uci set dhcp.lan.dynamicdhcp=0

# 3. تعطيل IPv6
uci set dhcp.lan.ra=disabled
uci set dhcp.lan.dhcpv6=disabled
uci set dhcp.lan.ndp=disabled

# 4. تعيين IP ثابت (بدون Gateway)
uci set network.lan.proto=static
uci set network.lan.ipaddr=192.168.1.21
uci set network.lan.netmask=255.255.255.0
uci delete network.lan.gateway 2>/dev/null || true

# 5. عزل العملاء
uci set wireless.default_radio0.isolate=1
uci set wireless.default_radio0.disassoc_low_ack=0
if uci get wireless.default_radio1 >/dev/null 2>&1; then
    uci set wireless.default_radio1.isolate=1
    uci set wireless.default_radio1.disassoc_low_ack=0
fi

# 6. تعيين SSID
uci set wireless.default_radio0.ssid=promax
uci set wireless.default_radio0.encryption=none
if uci get wireless.default_radio1 >/dev/null 2>&1; then
    uci set wireless.default_radio1.ssid=promax_5G
    uci set wireless.default_radio1.encryption=none
fi

uci commit dhcp
uci commit network
uci commit wireless
exit 0
EOF
chmod +x package/base-files/files/etc/uci-defaults/99-set-ap-mode

# ==========================================
# 4. دمج خلفية الثيم وتفعيل Argon
# ==========================================
mkdir -p package/base-files/files/www/luci-static/argon/background/
if [ -f "$GITHUB_WORKSPACE/bg.jpg" ]; then
    cp "$GITHUB_WORKSPACE/bg.jpg" package/base-files/files/www/luci-static/argon/background/bg.jpg
    echo "✅ تم نسخ خلفية الثيم بنجاح."
else
    echo "⚠️ تحذير: لم يتم العثور على ملف bg.jpg."
fi

cat << 'EOF' > package/base-files/files/etc/uci-defaults/98-argon-theme
#!/bin/sh
uci set luci.main.mediaurlbase=/luci-static/argon
uci set argon.@global[0].bing_background=0
uci set argon.@global[0].mode=normal
uci commit luci
uci commit argon
exit 0
EOF
chmod +x package/base-files/files/etc/uci-defaults/98-argon-theme

# ==========================================
# 5. تعديل wireless.js (dBm + Status) - البحث في feeds و package
# ==========================================
WIRELESS_JS=$(find . -name "wireless.js" -path "*network*" 2>/dev/null | head -n 1)

if [ -n "$WIRELESS_JS" ] && [ -f "$WIRELESS_JS" ]; then
    echo "تم العثور على wireless.js في: $WIRELESS_JS"

    # فحص محتوى wireless.js
    echo "=== فحص محتوى wireless.js ==="
    grep -n "pwrlist" "$WIRELESS_JS" 2>/dev/null | head -n 5
    grep -n "getTXPower" "$WIRELESS_JS" 2>/dev/null | head -n 5
    echo "============================="

    # إضافة قيم dBm (النمط الرسمي)
    if grep -q "for (var i = 0; i < pwrlist.length; i++)" "$WIRELESS_JS"; then
        sed -i 's|for (var i = 0; i < pwrlist.length; i++)|for (var i = 27; i <= 40; i++) { pwrlist.push({dbm: i, mw: Math.round(Math.pow(10, (i-30)/10) * 1000)}); }; pwrlist = pwrlist.filter((v,i,a)=>a.findIndex(t=>(t.dbm===v.dbm))===i); for (var i = 0; i < pwrlist.length; i++)|g' "$WIRELESS_JS"
        echo "✅ تمت إضافة قيم dBm (النمط الرسمي)."
    else
        echo "⚠️ لم يتم العثور على نمط قائمة dBm."
    fi

    # تعديل Status (النمط الرسمي)
    sed -i 's|%d %s|uci.get("wireless", "radio0", "txpower") || radioNet.getTXPower()|g' "$WIRELESS_JS"

    if grep -q "uci.get(" "$WIRELESS_JS"; then
        echo "✅ تم تعديل Status."
    else
        echo "⚠️ لم يتم تعديل Status."
    fi

else
    echo "⚠️ لم يتم العثور على wireless.js."
fi

# ==========================================
# 6. تعطيل الخدمات (97)
# ==========================================
cat << 'EOF' > package/base-files/files/etc/uci-defaults/97-disable-router-services
#!/bin/sh
/etc/init.d/firewall disable 2>/dev/null || true
/etc/init.d/eoip disable 2>/dev/null || true
/etc/init.d/mwan3 disable 2>/dev/null || true
/etc/init.d/odhcpd disable 2>/dev/null || true
/etc/init.d/log disable 2>/dev/null || true
/etc/init.d/dnsmasq disable 2>/dev/null || true
exit 0
EOF
chmod +x package/base-files/files/etc/uci-defaults/97-disable-router-services

# ==========================================
# 7. إخفاء إعدادات SSH و Keys (الإصدارات الحديثة)
# ==========================================
echo "=== البحث عن ملفات SSH في LuCI ==="
find feeds/luci -name "*.js" 2>/dev/null | xargs grep -l "dropbear" 2>/dev/null | head -n 5
find feeds/luci -name "*.js" 2>/dev/null | xargs grep -l "SSH" 2>/dev/null | head -n 5
echo "=================================="

# إخفاء إعدادات Dropbear (SSH) من الواجهة
DROPBEAR_JS="feeds/luci/modules/luci-mod-system/htdocs/luci-static/resources/view/system/dropbear.js"
if [ -f "$DROPBEAR_JS" ]; then
    echo "✅ تم العثور على dropbear.js، جاري إخفاء محتواه..."
    echo "return L.Class.extend({ render: function() { return E('p', _('SSH settings are hidden.')); } });" > "$DROPBEAR_JS"
else
    echo "⚠️ لم يتم العثور على dropbear.js"
fi

# إخفاء مفاتيح SSH (SSH Keys) من الواجهة
SSHKEYS_JS="feeds/luci/modules/luci-mod-system/htdocs/luci-static/resources/view/system/sshkeys.js"
if [ -f "$SSHKEYS_JS" ]; then
    echo "✅ تم العثور على sshkeys.js، جاري إخفاء محتواه..."
    echo "return L.Class.extend({ render: function() { return E('p', _('SSH Keys settings are hidden.')); } });" > "$SSHKEYS_JS"
else
    echo "⚠️ لم يتم العثور على sshkeys.js"
fi

# ==========================================
# 8. تعيين طاقة 36 dBm والدولة (PA)
# ==========================================
cat << 'EOF' > package/base-files/files/etc/uci-defaults/99-fix-wifi-power
#!/bin/sh
uci -q batch << EOB
set wireless.@wifi-device[0].disabled=0
set wireless.@wifi-device[1].disabled=0
set wireless.@wifi-device[0].country=PA
set wireless.@wifi-device[1].country=PA
set wireless.@wifi-device[0].txpower=36
set wireless.@wifi-device[1].txpower=36
commit wireless
EOB
wifi reload
exit 0
EOF
chmod +x package/base-files/files/etc/uci-defaults/99-fix-wifi-power
