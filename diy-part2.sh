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
# 3. إعدادات وضع الـ Access Point والدولة - بدون VLAN وبدون Gateway
# ==========================================
mkdir -p package/base-files/files/etc/uci-defaults
cat << 'EOF' > package/base-files/files/etc/uci-defaults/99-set-ap-mode
#!/bin/sh

# 1. حذف واجهات الـ WAN تماماً وإبقاء LAN فقط
uci delete network.wan 2>/dev/null || true
uci delete network.wan6 2>/dev/null || true

# 2. تعطيل خدمة DHCP على واجهة LAN (لأن الميكروتك هو من سيوفر العناوين)
uci set dhcp.lan.ignore='1'
uci set dhcp.lan.dynamicdhcp='0'

# 3. تعطيل خدمات IPv6
uci set dhcp.lan.ra='disabled'
uci set dhcp.lan.dhcpv6='disabled'
uci set dhcp.lan.ndp='disabled'

# 4. تعيين عنوان IP ثابت للجهاز (بدون Gateway)
uci set network.lan.proto='static'
uci set network.lan.ipaddr='192.168.1.21'
uci set network.lan.netmask='255.255.255.0'
uci delete network.lan.gateway 2>/dev/null || true

# 5. إعدادات الواي فاي (عزل العملاء وإلغاء الفصل التلقائي)
uci set wireless.default_radio0.isolate='1'
uci set wireless.default_radio0.disassoc_low_ack='0'
if uci get wireless.default_radio1 >/dev/null 2>&1; then
    uci set wireless.default_radio1.isolate='1'
    uci set wireless.default_radio1.disassoc_low_ack='0'
fi

# 6. تعيين اسم الشبكة (SSID) وكلمة المرور (بدون كلمة مرور)
uci set wireless.default_radio0.ssid='promax'
uci set wireless.default_radio0.encryption='none'

if uci get wireless.default_radio1 >/dev/null 2>&1; then
    uci set wireless.default_radio1.ssid='promax_5G'
    uci set wireless.default_radio1.encryption='none'
fi

# حفظ التغييرات
uci commit dhcp
uci commit network
uci commit wireless
exit 0
EOF
chmod +x package/base-files/files/etc/uci-defaults/99-set-ap-mode

# ==========================================
# 4. دمج خلفية الثيم المخصصة (bg.img) وتفعيل ثيم Argon
# ==========================================
mkdir -p package/base-files/files/www/luci-static/argon/background/
if [ -f "$GITHUB_WORKSPACE/bg.img" ]; then
    cp "$GITHUB_WORKSPACE/bg.img" package/base-files/files/www/luci-static/argon/background/bg.jpg
    echo "✅ تم نسخ خلفية الثيم بنجاح."
else
    echo "⚠️ تحذير: لم يتم العثور على ملف bg.img في جذر المشروع."
fi

cat << 'EOF' > package/base-files/files/etc/uci-defaults/98-argon-theme
#!/bin/sh
uci set luci.main.mediaurlbase='/luci-static/argon'
uci set argon.@global[0].bing_background='0'
uci set argon.@global[0].mode='normal'
uci commit luci
uci commit argon
exit 0
EOF
chmod +x package/base-files/files/etc/uci-defaults/98-argon-theme

# ==========================================
# 5. تخصيص سلوك اللمبات (LEDs): إضاءة اللمبتين برتقالي عند البدء ثم الاستقرار على لمبة واحدة
# ==========================================
cat << 'EOF' > package/base-files/files/etc/uci-defaults/97-custom-leds
#!/bin/sh
# ضبط إضاءة اللمبات عند الإقلاع والاستقرار
for led in /sys/class/leds/*; do
    if [ -d "$led" ]; then
        # إعطاء إشارة البداية
        echo 255 > "$led/brightness" 2>/dev/null || true
    fi
done
# الاستقرار على لمبة التشغيل الأساسية وإطفاء البقية بعد الإقلاع
sleep 2
for led in /sys/class/leds/*; do
    if [ -d "$led" ]; then
        echo 0 > "$led/brightness" 2>/dev/null || true
    fi
done
# تفعيل لمبة الحالة أو الطاقة المحددة فقط
if [ -d "/sys/class/leds/*power*" ]; then
    echo 255 > /sys/class/leds/*power*/brightness 2>/dev/null || true
elif [ -d "/sys/class/leds/*status*" ]; then
    echo 255 > /sys/class/leds/*status*/brightness 2>/dev/null || true
fi
exit 0
EOF
chmod +x package/base-files/files/etc/uci-defaults/97-custom-leds

# ==========================================
# 6. حقن ورفع سقف القيم في واجهة LuCI لتشمل 36 dBm (وهمية/عرض فقط)
# ==========================================
WIRELESS_JS=$(find . -name "wireless.js" -path "*network*" 2>/dev/null | head -n 1)

if [ -n "$WIRELESS_JS" ] && [ -f "$WIRELESS_JS" ]; then
    echo "تم العثور على wireless.js في: $WIRELESS_JS"
    
    if grep -q "for(let p of pwrlist)" "$WIRELESS_JS"; then
        sed -i "s|for(let p of pwrlist)|for(let i=27; i<=36; i++) { pwrlist.push({dbm: i, mw: Math.round(Math.pow(10, (i-30)/10) * 1000)}); }; pwrlist = pwrlist.filter((v,i,a)=>a.findIndex(t=>(t.dbm===v.dbm))===i); for(let p of pwrlist)|g" "$WIRELESS_JS"
        echo "✅ تم حقن القيم حتى 36 dBm للإصدار الحديث."
    elif grep -q "for(var i=0;i<pwrlist.length;i++)" "$WIRELESS_JS"; then
        sed -i "s|for(var i=0;i<pwrlist.length;i++)|for(let j=27; j<=36; j++) { pwrlist.push({dbm: j, mw: Math.round(Math.pow(10, (j-30)/10) * 1000)}); }; pwrlist = pwrlist.filter((v,i,a)=>a.findIndex(t=>(t.dbm===v.dbm))===i); for(var i=0;i<pwrlist.length;i++)|g" "$WIRELESS_JS"
        echo "✅ تم حقن القيم حتى 36 dBm للإصدار القديم."
    else
        echo "⚠️ لم يتم العثور على النمط المناسب لحقن القيم."
    fi
else
    echo "⚠️ لم يتم العثور على ملف wireless.js."
fi

# ==========================================
# 7. تعطيل الخدمات غير الضرورية (مع إبقاء SSH يعمل)
# ==========================================
cat << 'EOF' > package/base-files/files/etc/uci-defaults/98-disable-router-services
#!/bin/sh
/etc/init.d/firewall disable 2>/dev/null || true
/etc/init.d/eoip disable 2>/dev/null || true
/etc/init.d/mwan3 disable 2>/dev/null || true
/etc/init.d/odhcpd disable 2>/dev/null || true
/etc/init.d/log disable 2>/dev/null || true
/etc/init.d/dnsmasq disable 2>/dev/null || true
exit 0
EOF
chmod +x package/base-files/files/etc/uci-defaults/98-disable-router-services

# ==========================================
# 8. إخفاء خيارات SSH والـ Keys بشكل جذري من واجهة LuCI
# ==========================================
rm -f feeds/luci/modules/luci-mod-system/luasrc/controller/admin/keys.lua 2>/dev/null || true
find . -name "keys.lua" -exec rm -f {} \; 2>/dev/null || true

if [ -f "feeds/luci/collections/luci/Makefile" ]; then
    sed -i 's/luci-theme-bootstrap/luci-theme-argon/g' feeds/luci/collections/luci/Makefile 2>/dev/null || true
fi

# ==========================================
# 9. تعيين طاقة الإرسال على 36 dBm وإلغاء قيود الدولة ('US')
# ==========================================
cat << 'EOF' > package/base-files/files/etc/uci-defaults/99-fix-wifi-power
#!/bin/sh
uci -q batch << EOB
set wireless.@wifi-device[0].disabled='0'
set wireless.@wifi-device[1].disabled='0'
set wireless.@wifi-device[0].country='US'
set wireless.@wifi-device[1].country='US'
set wireless.@wifi-device[0].txpower='36'
set wireless.@wifi-device[1].txpower='36'
commit wireless
EOB
wifi reload
exit 0
EOF
chmod +x package/base-files/files/etc/uci-defaults/99-fix-wifi-power
