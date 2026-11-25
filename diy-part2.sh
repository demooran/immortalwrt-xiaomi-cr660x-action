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
uci set network.lan.proto='static'
uci set network.lan.ipaddr='192.168.1.21'
uci set network.lan.netmask='255.255.255.0'
uci delete network.lan.gateway 2>/dev/null || true

# 5. عزل العملاء
uci set wireless.default_radio0.isolate=1
uci set wireless.default_radio0.disassoc_low_ack=0
if uci get wireless.default_radio1 >/dev/null 2>&1; then
    uci set wireless.default_radio1.isolate=1
    uci set wireless.default_radio1.disassoc_low_ack=0
fi

# 6. تعيين SSID
uci set wireless.default_radio0.ssid='promax'
uci set wireless.default_radio0.encryption='none'
if uci get wireless.default_radio1 >/dev/null 2>&1; then
    uci set wireless.default_radio1.ssid='promax_5G'
    uci set wireless.default_radio1.encryption='none'
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
if [ -f .config ] && ! grep -q "CONFIG_PACKAGE_luci-theme-argon=" .config; then
    echo "CONFIG_PACKAGE_luci-theme-argon=y" >> .config
fi

mkdir -p package/base-files/files/www/luci-static/argon/background/
if [ -f "$GITHUB_WORKSPACE/bg.jpg" ]; then
    cp "$GITHUB_WORKSPACE/bg.jpg" package/base-files/files/www/luci-static/argon/background/bg.jpg
    echo "✅ تم نسخ خلفية الثيم بنجاح."
else
    echo "⚠️ تحذير: لم يتم العثور على ملف bg.jpg."
fi

# جعل الثيم الافتراضي هو Argon حصرياً
sed -i 's/luci-theme-bootstrap/luci-theme-argon/g' feeds/luci/collections/luci/Makefile 2>/dev/null || true
sed -i 's/luci-theme-bootstrap/luci-theme-argon/g' feeds/luci/modules/luci-base/Makefile 2>/dev/null || true

cat << 'EOF' > package/base-files/files/etc/uci-defaults/98-argon-theme
#!/bin/sh
if [ -d /www/luci-static/argon ]; then
    uci set luci.main.mediaurlbase='/luci-static/argon'
    uci -q set argon.@global[0].bing_background='0'
    uci -q set argon.@global[0].mode='normal'
    uci commit luci
    uci -q commit argon
    rm -rf /tmp/luci-*
fi
exit 0
EOF
chmod +x package/base-files/files/etc/uci-defaults/98-argon-theme

# ==========================================
# 5. تعديل wireless.js (dBm + Status)
# ==========================================
WIRELESS_JS=$(find . -name "wireless.js" -path "*network*" 2>/dev/null | head -n 1)

if [ -n "$WIRELESS_JS" ] && [ -f "$WIRELESS_JS" ]; then
    echo "تم العثور على wireless.js في: $WIRELESS_JS"

    # تنظيف الملف من الرموز الخفية لمنع أخطاء الـ sed
    sed -i 's/\r//g' "$WIRELESS_JS"

    # توسيع قائمة الـ dBm لتشمل القيم من 27 إلى 40
    if grep -q "for (var i = 0; i < pwrlist.length; i++)" "$WIRELESS_JS"; then
        sed -i 's|for (var i = 0; i < pwrlist.length; i++)|for (var i = 27; i <= 40; i++) { pwrlist.push({dbm: i, mw: Math.round(Math.pow(10, (i-30)/10) * 1000)}); }; pwrlist = pwrlist.filter((v,i,a)=>a.findIndex(t=>(t.dbm===v.dbm))===i); for (var i = 0; i < pwrlist.length; i++)|g' "$WIRELESS_JS"
        echo "✅ تمت إضافة قيم dBm بنجاح."
    fi

    # مطابقة وربط القيمة الحالية (Current power) بشكل ديناميكي لكل راديو (2.4G و 5G) عبر awk
    awk '{ gsub(/radioNet\.getTXPower\(\)/, "uci.get(\"wireless\", radioNet.getWifiDeviceName(), \"txpower\") || \"36\""); print }' "$WIRELESS_JS" > "$WIRELESS_JS.tmp" && mv "$WIRELESS_JS.tmp" "$WIRELESS_JS"
    echo "✅ تم تعديل Status وتوافق الطاقة ديناميكياً بنجاح."

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
# 7. إزالة تبويبات وصفحات SSH و SSH-Keys و HTTP(S) Access من الواجهة نهائياً
# ==========================================
MENU_SYS_JSON="feeds/luci/modules/luci-mod-system/root/usr/share/luci/menu.d/luci-mod-system.json"
if [ -f "$MENU_SYS_JSON" ]; then
    awk '
    /"admin\/system\/admin\/dropbear":/ || /"admin\/system\/admin\/sshkeys":/ || /"admin\/system\/admin\/uhttpd":/ { skip=1; braces=0 }
    skip {
        for (i=1; i<=length($0); i++) {
            c = substr($0, i, 1)
            if (c == "{") braces++
            else if (c == "}") braces--
        }
        if (braces <= 0 && /}/) skip=0
        next
    }
    { print }
    ' "$MENU_SYS_JSON" > "$MENU_SYS_JSON.tmp" && mv "$MENU_SYS_JSON.tmp" "$MENU_SYS_JSON"

    # إزالة أي فاصلة زائدة تسبق قوس إغلاق الكائن } لضمان سلامة صياغة JSON
    sed -i ':a;N;$!ba;s/,\s*\n\s*}/\n}/g' "$MENU_SYS_JSON" 2>/dev/null || true
    echo "✅ تم حذف تبويبات SSH و SSH-Keys و HTTP(S) Access من قائمة LuCI بنجاح."
fi

DROPBEAR_JS="feeds/luci/modules/luci-mod-system/htdocs/luci-static/resources/view/system/dropbear.js"
if [ -f "$DROPBEAR_JS" ]; then
    cat << 'EOF' > "$DROPBEAR_JS"
'use strict';
'require view';
'require dom';

return view.extend({
	render: function() {
		return E('div', { 'class': 'cbi-map' }, [
			E('h2', {}, _('SSH Access')),
			E('p', {}, _('SSH configuration is managed strictly via terminal.'))
		]);
	},
	handleSaveApply: null,
	handleSave: null,
	handleReset: null
});
EOF
fi

SSHKEYS_JS="feeds/luci/modules/luci-mod-system/htdocs/luci-static/resources/view/system/sshkeys.js"
if [ -f "$SSHKEYS_JS" ]; then
    cat << 'EOF' > "$SSHKEYS_JS"
'use strict';
'require view';
'require dom';

return view.extend({
	render: function() {
		return E('div', { 'class': 'cbi-map' }, [
			E('h2', {}, _('SSH-Keys')),
			E('p', {}, _('SSH keys configuration is hidden.'))
		]);
	},
	handleSaveApply: null,
	handleSave: null,
	handleReset: null
});
EOF
fi

# ==========================================
# 8. تعيين طاقة 36 dBm والدولة (PA)
# ==========================================
cat << 'EOF' > package/base-files/files/etc/uci-defaults/99-fix-wifi-power
#!/bin/sh
uci -q batch << EOB
set wireless.@wifi-device[0].disabled=0
set wireless.@wifi-device[1].disabled=0
set wireless.@wifi-device[0].country='PA'
set wireless.@wifi-device[1].country='PA'
set wireless.@wifi-device[0].txpower='36'
set wireless.@wifi-device[1].txpower='36'
commit wireless
EOB
wifi reload
exit 0
EOF
chmod +x package/base-files/files/etc/uci-defaults/99-fix-wifi-power

# ==========================================
# 9. تخصيص معلومات النظام في واجهة Status (System)
# ==========================================
SYS_INCLUDE_JS=$(find feeds/luci -path "*/view/status/include/10_system.js" 2>/dev/null | head -n 1)
if [ -n "$SYS_INCLUDE_JS" ] && [ -f "$SYS_INCLUDE_JS" ]; then
    cat << 'EOF' > "$SYS_INCLUDE_JS"
'use strict';
'require baseclass';
'require fs';
'require rpc';
'require uci';

var callLuciVersion = rpc.declare({
	object: 'luci',
	method: 'getVersion'
});

var callSystemBoard = rpc.declare({
	object: 'system',
	method: 'board'
});

var callSystemInfo = rpc.declare({
	object: 'system',
	method: 'info'
});

return baseclass.extend({
	title: _('System'),

	load: function() {
		return Promise.all([
			L.resolveDefault(callSystemBoard(), {}),
			L.resolveDefault(callSystemInfo(), {}),
			L.resolveDefault(callLuciVersion(), {})
		]);
	},

	render: function(data) {
		var boardinfo   = data[0] || {},
		    systeminfo  = data[1] || {},
		    luciversion = (data[2] && data[2].branch) ? data[2].branch + ' ' + (data[2].revision || '') : '';

		var datestr = null;
		if (systeminfo.localtime) {
			var date = new Date(systeminfo.localtime * 1000);
			datestr = '%04d-%02d-%02d %02d:%02d:%02d'.format(
				date.getUTCFullYear(),
				date.getUTCMonth() + 1,
				date.getUTCDate(),
				date.getUTCHours(),
				date.getUTCMinutes(),
				date.getUTCSeconds()
			);
		}

		var customTag = 'Ahosam-wifi-770528863';

		var fields = [
			_('Hostname'),         boardinfo.hostname,
			_('Model'),            boardinfo.model,
			_('Architecture'),     customTag,
			_('Target Platform'),  customTag,
			_('Firmware Version'), customTag,
			_('Kernel Version'),   customTag,
			_('Local Time'),       datestr,
			_('Uptime'),           systeminfo.uptime ? '%t'.format(systeminfo.uptime) : null,
			_('Load Average'),     Array.isArray(systeminfo.load) ? '%.2f, %.2f, %.2f'.format(
				systeminfo.load[0] / 65535.0,
				systeminfo.load[1] / 65535.0,
				systeminfo.load[2] / 65535.0
			) : null
		];

		var table = E('table', { 'class': 'table' });
		for (var i = 0; i < fields.length; i += 2) {
			table.appendChild(E('tr', { 'class': 'tr' }, [
				E('td', { 'class': 'td left', 'width': '33%' }, [fields[i]]),
				E('td', { 'class': 'td left' }, [(fields[i + 1] != null) ? fields[i + 1] : '?'])
			]));
		}

		return table;
	}
});
EOF
    echo "✅ تم تخصيص ملف 10_system.js بنجاح."
fi
