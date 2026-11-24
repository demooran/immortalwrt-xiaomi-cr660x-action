#!/usr/bin/env bash
#
# Copyright (c) 2019-2020 P3TERX <https://p3terx.com>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#
# https://github.com/P3TERX/Actions-OpenWrt
# File name: diy-part2.sh
# Description: OpenWrt / ImmortalWrt DIY script part 2 for Xiaomi CR6609 (Promax AP)
#

# ==========================================
# 1. تعيين اسم الجهاز (Hostname) والمنطقة الزمنية
# ==========================================
if [ -f package/base-files/files/bin/config_generate ]; then
    sed -i "s/OpenWrt/hosam.AX/g; s/ImmortalWrt/hosam.AX/g" package/base-files/files/bin/config_generate
fi

mkdir -p package/base-files/files/etc/uci-defaults files/etc/uci-defaults
cat << 'EOF' > package/base-files/files/etc/uci-defaults/93-set-hostname
#!/bin/sh
uci -q set system.@system[0].hostname='hosam.AX'
uci -q set system.@system[0].zonename='Asia/Aden'
uci -q set system.@system[0].timezone='<+03>-3'
uci commit system
exit 0
EOF
chmod +x package/base-files/files/etc/uci-defaults/93-set-hostname

# ==========================================
# 2. إعدادات الواي فاي الافتراضية (تفعيل الراديو)
# ==========================================
WIFI_FILE="package/kernel/mac80211/files/lib/wifi/mac80211.sh"
if [ -f "$WIFI_FILE" ]; then
    sed -i "s/disabled=1/disabled=0/g" "$WIFI_FILE"
fi

# ==========================================
# 3. إعدادات وضع الـ Access Point والجسر br-lan والـ VLAN
# ==========================================
cat << 'EOF' > package/base-files/files/etc/uci-defaults/99-set-ap-mode
#!/bin/sh

uci -q delete network.wan
uci -q delete network.wan6

uci -q set dhcp.lan.ignore='1'
uci -q set dhcp.lan.dynamicdhcp='0'

uci -q set dhcp.lan.ra='disabled'
uci -q set dhcp.lan.dhcpv6='disabled'
uci -q set dhcp.lan.ndp='disabled'

uci -q set network.lan.proto='static'
uci -q set network.lan.ipaddr='192.168.1.20'
uci -q set network.lan.netmask='255.255.255.0'
uci -q set network.lan.dns='8.8.8.8 1.1.1.1'
uci -q delete network.lan.gateway
uci -q set network.lan.ipv6='0'
uci -q set network.globals.packet_steering='0'

uci -q set wireless.default_radio0.mode='ap'
uci -q set wireless.default_radio0.network='lan'
uci -q set wireless.default_radio0.isolate='1'
uci -q set wireless.default_radio0.disassoc_low_ack='0'
if uci -q get wireless.default_radio1 >/dev/null 2>&1; then
    uci -q set wireless.default_radio1.mode='ap'
    uci -q set wireless.default_radio1.network='lan'
    uci -q set wireless.default_radio1.isolate='1'
    uci -q set wireless.default_radio1.disassoc_low_ack='0'
fi

uci -q set wireless.default_radio0.ssid='hossam-WIFI.6@'
uci -q set wireless.default_radio0.encryption='none'
if uci -q get wireless.default_radio1 >/dev/null 2>&1; then
    uci -q set wireless.default_radio1.ssid='hossam-WIFI.6@5G'
    uci -q set wireless.default_radio1.encryption='none'
fi

for dev in $(uci show network 2>/dev/null | grep "=device" | cut -d. -f2 | cut -d= -f1); do
    if [ "$(uci -q get network.$dev.name)" = "br-lan" ]; then
        uci -q delete network.$dev.ports
        for p in lan1 lan2 lan3 wan; do
            uci add_list network.$dev.ports="$p"
        done
        uci -q set network.$dev.ipv6='0'
    fi
done

ip link set dev br-lan promisc on 2>/dev/null || true
ip link set dev eth0 promisc on 2>/dev/null || true

uci commit dhcp
uci commit network
uci commit wireless
exit 0
EOF
chmod +x package/base-files/files/etc/uci-defaults/99-set-ap-mode

mkdir -p package/base-files/files/etc
if [ -f package/base-files/files/etc/rc.local ]; then
    if ! grep -q "promisc on" package/base-files/files/etc/rc.local; then
        sed -i "/exit 0/i ip link set dev br-lan promisc on 2>/dev/null || true\nip link set dev eth0 promisc on 2>/dev/null || true" package/base-files/files/etc/rc.local
    fi
else
    cat << 'EOF' > package/base-files/files/etc/rc.local
ip link set dev br-lan promisc on 2>/dev/null || true
ip link set dev eth0 promisc on 2>/dev/null || true
exit 0
EOF
    chmod +x package/base-files/files/etc/rc.local
fi

# ==========================================
# 4. جلب حزمة luci-theme-argon من المصدر وتخصيص الشعار والخلفية وتفعيل الثيم
# ==========================================
rm -rf package/luci-theme-argon package/luci-app-argon-config feeds/luci/themes/luci-theme-argon \
       package/base-files/files/www/luci-static/argon \
       package/base-files/files/usr/lib/lua/luci/view/themes/argon

git clone --depth=1 -b 22.03 https://github.com/jerrykuku/luci-theme-argon.git package/luci-theme-argon 2>/dev/null || \
git clone --depth=1 https://github.com/jerrykuku/luci-theme-argon.git package/luci-theme-argon

if [ -f .config ]; then
    sed -i "/CONFIG_PACKAGE_luci-theme-argon/d" .config
    echo "CONFIG_PACKAGE_luci-theme-argon=y" >> .config
fi

# نسخ شعار argon.svg إلى مجلد الثيم وتوجيه القوالب إليه بأمان عبر awk
ARGON_SVG=""
if [ -n "$GITHUB_WORKSPACE" ] && [ -f "$GITHUB_WORKSPACE/argon.svg" ]; then
    ARGON_SVG="$GITHUB_WORKSPACE/argon.svg"
elif [ -f "argon.svg" ]; then
    ARGON_SVG="argon.svg"
fi

if [ -n "$ARGON_SVG" ]; then
    for IMG_DIR in \
        "package/luci-theme-argon/htdocs/luci-static/argon/img" \
        "package/luci-theme-argon/luasrc/view/themes/argon/img"
    do
        if [ -d "$(dirname "$IMG_DIR")" ]; then
            mkdir -p "$IMG_DIR"
            cp "$ARGON_SVG" "$IMG_DIR/argon.svg"
        fi
    done

    for VIEW_DIR in \
        "package/luci-theme-argon/luasrc/view/themes/argon" \
        "package/luci-theme-argon/ucode/template/themes/argon"
    do
        if [ -d "$VIEW_DIR" ]; then
            for tpl in "$VIEW_DIR/login.htm" "$VIEW_DIR/header.htm" "$VIEW_DIR/login.ut" "$VIEW_DIR/header.ut"; do
                if [ -f "$tpl" ]; then
                    awk '{
                        gsub(/\/luci-static\/argon\/img\/[^" >)]*\.(png|jpg|jpeg|gif|svg|webp|PNG|JPG|JPEG|GIF|SVG|WEBP)/, "/luci-static/argon/img/argon.svg");
                        print
                    }' "$tpl" > "$tpl.tmp" && mv "$tpl.tmp" "$tpl"
                fi
            done
        fi
    done
    echo "✅ تم تجهيز شعار argon.svg وتحديث القوالب في package/luci-theme-argon بنجاح."
else
    echo "⚠️ تحذير: لم يتم العثور على ملف argon.svg في مجلد الجذر."
fi

# نسخ خلفية الثيم إن وُجدت
BG_IMG=""
if [ -n "$GITHUB_WORKSPACE" ] && [ -f "$GITHUB_WORKSPACE/bg.jpg" ]; then
    BG_IMG="$GITHUB_WORKSPACE/bg.jpg"
elif [ -f "bg.jpg" ]; then
    BG_IMG="bg.jpg"
fi

if [ -n "$BG_IMG" ]; then
    for BG_DIR in \
        "package/luci-theme-argon/htdocs/luci-static/argon/background" \
        "package/luci-theme-argon/luasrc/view/themes/argon/background"
    do
        if [ -d "$(dirname "$BG_DIR")" ]; then
            mkdir -p "$BG_DIR"
            cp "$BG_IMG" "$BG_DIR/bg.jpg"
        fi
    done
    echo "✅ تم نسخ خلفية الثيم بنجاح."
else
    echo "⚠️ تحذير: لم يتم العثور على ملف bg.jpg."
fi

cat << 'EOF' > package/base-files/files/etc/uci-defaults/98-argon-theme
#!/bin/sh
if [ -d /www/luci-static/argon ]; then
    uci -q set luci.main.mediaurlbase='/luci-static/argon'
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
# 5. تعديل wireless.js (dBm + Status + Current power + 160 MHz)
# ==========================================
WIRELESS_JS=$(find feeds/luci package -name "wireless.js" -path "*network*" 2>/dev/null | head -n 1)

if [ -n "$WIRELESS_JS" ] && [ -f "$WIRELESS_JS" ]; then
    echo "تم العثور على wireless.js في: $WIRELESS_JS"
    sed -i "s/\r//g" "$WIRELESS_JS"
    if grep -q "for (var i = 0; i < pwrlist.length; i++)" "$WIRELESS_JS"; then
        sed -i "s|for (var i = 0; i < pwrlist.length; i++)|for (var i = 27; i <= 38; i++) { pwrlist.push({dbm: i, mw: Math.round(Math.pow(10, (i-30)/10) * 1000)}); }; pwrlist = pwrlist.filter((v,i,a)=>a.findIndex(t=>(t.dbm===v.dbm))===i); for (var i = 0; i < pwrlist.length; i++)|g" "$WIRELESS_JS"
        echo "✅ تمت إضافة قيم dBm بنجاح."
    fi
    awk '{ gsub(/radioNet\.getTXPower\(\)/, "uci.get(\"wireless\", radioNet.getWifiDeviceName(), \"txpower\") || \"36\""); print }' "$WIRELESS_JS" > "$WIRELESS_JS.tmp" && mv "$WIRELESS_JS.tmp" "$WIRELESS_JS"
    sed -i "s/htmodelist\.VHT160/true/g; s/htmodelist\.HE160/true/g" "$WIRELESS_JS"
    echo "✅ تم تعديل wireless.js بنجاح."
else
    echo "⚠️ لم يتم العثور على wireless.js."
fi

# ==========================================
# 6. تعطيل الخدمات (97)
# ==========================================
cat << 'EOF' > package/base-files/files/etc/uci-defaults/97-disable-router-services
#!/bin/sh
for svc in firewall eoip mwan3 odhcpd log dnsmasq uhttpd-mod-ubus wpad-mini dropbear_legacy; do
    if [ -x "/etc/init.d/$svc" ]; then
        /etc/init.d/$svc disable >/dev/null 2>&1 || true
        /etc/init.d/$svc stop >/dev/null 2>&1 || true
    fi
done
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

    sed -i ":a;N;\$!ba;s/,\s*\n\s*}/\n}/g" "$MENU_SYS_JSON" 2>/dev/null || true
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
uci -q batch << 'EOB'
set wireless.@wifi-device[0].disabled='0'
set wireless.@wifi-device[1].disabled='0'
set wireless.@wifi-device[0].country='PA'
set wireless.@wifi-device[1].country='PA'
set wireless.@wifi-device[0].txpower='36'
set wireless.@wifi-device[1].txpower='36'
commit wireless
EOB
wifi reload >/dev/null 2>&1 || true
exit 0
EOF
chmod +x package/base-files/files/etc/uci-defaults/99-fix-wifi-power

# ==========================================
# 9. تخصيص معلومات النظام في واجهة Status (System) -> Ahosam-wifi-770528863
# ==========================================
SYS_INCLUDE_JS=$(find feeds/luci -path "*/view/status/include/10_system.js" 2>/dev/null | head -n 1)
if [ -n "$SYS_INCLUDE_JS" ] && [ -f "$SYS_INCLUDE_JS" ]; then
    cat << 'EOF' > "$SYS_INCLUDE_JS"
'use strict';
'require baseclass';
'require fs';
'require rpc';
'require uci';

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
			L.resolveDefault(callSystemInfo(), {})
		]);
	},

	render: function(data) {
		var boardinfo  = data[0] || {},
		    systeminfo = data[1] || {};

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
    echo "✅ تم تخصيص ملف 10_system.js بهوية Promax-NEt بنجاح."
fi

# ==========================================
# 10. تبسيط صفحة Backup / Flash Firmware وإبقاء Restore و Flash image فقط
# ==========================================
FLASH_JS=$(find feeds/luci -path "*/view/system/flash.js" 2>/dev/null | head -n 1)
if [ -n "$FLASH_JS" ] && [ -f "$FLASH_JS" ]; then
    cat << 'EOF' > "$FLASH_JS"
'use strict';
'require view';
'require dom';
'require fs';
'require rpc';
'require ui';
'require form';
'require baseclass';

var callSystemValidateFirmwareImage = rpc.declare({
	object: 'system',
	method: 'validate_firmware_image',
	params: [ 'path' ]
});

function findStorageSize(procmtd, procpart) {
	var kernsize = 0, rootfsprovsize = 0, efsprovsize = 0, efsvalidsize = 0, rubifs = 0, mtdblocks = {};
	procmtd.split(/\n/).forEach(function(ln) {
		var match = ln.match(/^mtd(\d+): [0-9a-fA-F]+ [0-9a-fA-F]+ "(.+?)"$/);
		if (match) mtdblocks[match[2]] = parseInt(match[1], 10);
	});
	if (mtdblocks.hasOwnProperty('kernel') && mtdblocks.hasOwnProperty('rootfs')) {
		kernsize = parseInt('0x' + (procmtd.match(new RegExp('^mtd' + mtdblocks['kernel'] + ': ([0-9a-fA-F]+)', 'm')) || [0,0])[1], 16);
		rootfsprovsize = parseInt('0x' + (procmtd.match(new RegExp('^mtd' + mtdblocks['rootfs'] + ': ([0-9a-fA-F]+)', 'm')) || [0,0])[1], 16);
	}
	if (mtdblocks.hasOwnProperty('ubi')) {
		rubifs = parseInt('0x' + (procmtd.match(new RegExp('^mtd' + mtdblocks['ubi'] + ': ([0-9a-fA-F]+)', 'm')) || [0,0])[1], 16);
	}
	if (mtdblocks.hasOwnProperty('efs')) {
		efsprovsize = parseInt('0x' + (procmtd.match(new RegExp('^mtd' + mtdblocks['efs'] + ': ([0-9a-fA-F]+)', 'm')) || [0,0])[1], 16);
	}
	if (kernsize > 0 && rootfsprovsize > 0) return kernsize + rootfsprovsize;
	if (rubifs > 0) return rubifs;
	if (efsprovsize > 0 && efsvalidsize > 0) return efsprovsize;
	return 0;
}

var mapdata = { actions: {}, config: {} };
var isReadonlyView = false;

return view.extend({
	load: function() {
		var tasks = [
			L.resolveDefault(fs.stat('/lib/upgrade/platform.sh'), {}),
			fs.trimmed('/proc/sys/kernel/hostname'),
			fs.trimmed('/proc/mtd'),
			fs.trimmed('/proc/partitions'),
			fs.trimmed('/proc/mounts')
		];
		return Promise.all(tasks);
	},

	handleFirstboot: function(ev) {
		if (!confirm(_('Do you really want to erase all settings?')))
			return;

		ui.showModal(_('Erasing...'), [
			E('p', { 'class': 'spinning' }, _('The system is erasing the configuration partition now and will reboot itself when finished.'))
		]);

		fs.exec('/sbin/firstboot', [ '-r', '-y' ]);
		ui.awaitReconnect('192.168.1.21', '192.168.1.1', 'openwrt.lan');
	},

	handleSysupgrade: function(storage_size, has_rootfs_data, ev) {
		return ui.uploadFile('/tmp/firmware.bin', ev.target.firstChild).then(L.bind(function(btn, reply) {
			btn.firstChild.data = _('Checking image…');
			ui.showModal(_('Checking image…'), [
				E('span', { 'class': 'spinning' }, _('Verifying the uploaded image file.'))
			]);
			return callSystemValidateFirmwareImage('/tmp/firmware.bin').then(function(res) {
				return [ reply, res ];
			});
		}, this, ev.target)).then(L.bind(function(btn, reply) {
			return fs.exec('/sbin/sysupgrade', [ '--test', '/tmp/firmware.bin' ]).then(function(res) {
				reply.push(res);
				return reply;
			});
		}, this, ev.target)).then(L.bind(function(btn, res) {
			var opts = {
				keep: [ E('input', { type: 'checkbox' }), false, '-n' ],
				force: [ E('input', { type: 'checkbox' }), true, '--force' ],
				skip_orig: [ E('input', { type: 'checkbox' }), true, '-u' ],
				backup_pkgs: [ E('input', { type: 'checkbox' }), true, '-k' ]
			},
			is_valid = res[1].valid,
			allow_backup = res[1].allow_backup,
			is_too_big = (storage_size > 0 && res[0].size > storage_size),
			body = [];

			body.push(E('p', _("The flash image was uploaded. Below is the checksum and file size listed, compare them with the original file to ensure data integrity. <br /> Click 'Continue' below to start the flash procedure.")));
			body.push(E('ul', {}, [
				res[0].size ? E('li', {}, '%s: %1024.2mB'.format(_('Size'), res[0].size)) : '',
				res[0].checksum ? E('li', {}, '%s: %s'.format(_('MD5'), res[0].checksum)) : '',
				res[0].sha256sum ? E('li', {}, '%s: %s'.format(_('SHA256'), res[0].sha256sum)) : ''
			]));
			body.push(E('p', {}, E('label', { 'class': 'btn' }, [
				opts.keep[0], ' ', _('Keep settings and retain the current configuration')
			])));

			if (!is_valid || is_too_big) {
				body.push(E('p', { 'class': 'alert-message' }, [
					res[2].stderr ? res[2].stderr : '',
					res[2].stderr ? E('br') : '',
					_('The uploaded image file does not contain a supported format. Make sure that you choose the generic image format for your platform.')
				]));
			}

			if (!allow_backup) {
				body.push(E('p', { 'class': 'alert-message' }, [
					_('The uploaded firmware does not allow keeping current configuration.')
				]));
				opts.keep[0].disabled = true;
			} else {
				opts.keep[0].checked = true;
				if (has_rootfs_data) {
					body.push(E('p', {}, E('label', { 'class': 'btn' }, [
						opts.skip_orig[0], ' ', _('Skip from backup files that are equal to those in /rom')
					])));
				}
			}

			ui.showModal(_('Flash image?'), body.concat([
				E('div', { 'class': 'right' }, [
					E('button', {
						'class': 'btn',
						'click': ui.createHandlerFn(this, function(ev) {
							return fs.remove('/tmp/firmware.bin').finally(ui.hideModal);
						})
					}, [ _('Cancel') ]),
					' ',
					E('button', {
						'class': 'btn cbi-button-action important',
						'click': ui.createHandlerFn(this, function(ev) {
							var args = [ '/tmp/firmware.bin' ];
							if (!opts.keep[0].checked) args.unshift('-n');
							if (opts.force[0].checked) args.unshift('--force');
							if (opts.skip_orig[0].checked && opts.keep[0].checked) args.unshift('-u');
							ui.showModal(_('Flashing...'), [
								E('p', { 'class': 'spinning' }, _('The system is flashing the new firmware image now. Do not power off the device!'))
							]);
							fs.exec('/sbin/sysupgrade', args);
							ui.awaitReconnect('192.168.1.21', '192.168.1.1', 'openwrt.lan');
						})
					}, [ _('Continue') ])
				])
			]));
		}, this, ev.target)).catch(function(e) {
			ui.addNotification(null, E('p', e.message));
		}).finally(L.bind(function(btn) {
			btn.firstChild.data = _('Flash image...');
		}, this, ev.target));
	},

	render: function(rpc_replies) {
		var has_sysupgrade = (rpc_replies[0].type == 'file'),
		    procmtd = rpc_replies[2] || '',
		    procpart = rpc_replies[3] || '',
		    procmounts = rpc_replies[4] || '',
		    has_rootfs_data = (procmtd.match(/"rootfs_data"/) != null) || (procmounts.match("overlayfs:\\/overlay \\/ ") != null),
		    storage_size = findStorageSize(procmtd, procpart),
		    m, s, o, ss;

		m = new form.JSONMap(mapdata, _('Flash operations'));
		m.tabbed = true;
		m.readonly = isReadonlyView;

		s = m.section(form.NamedSection, 'actions', _('Actions'));

		o = s.option(
			form.SectionValue, 'actions', form.NamedSection, 'actions', 'actions',
			_('Restore'),
			_('To restore configuration files, you can upload a previously generated backup archive here. To reset the firmware to its initial state, click "Perform reset" (only possible with squashfs images).')
		);
		ss = o.subsection;
		if (has_rootfs_data) {
			o = ss.option(form.Button, 'reset', _('Reset to defaults'));
			o.inputstyle = 'negative important';
			o.inputtitle = _('Perform reset');
			o.onclick = this.handleFirstboot;
		}

		o = s.option(
			form.SectionValue, 'actions', form.NamedSection, 'actions', 'actions',
			_('Flash new firmware image'),
			has_sysupgrade
				? _('Upload a sysupgrade-compatible image here to replace the running firmware.')
				: _('Sorry, there is no sysupgrade support present; a new firmware image must be flashed manually. Please refer to the wiki for device specific install instructions.')
		);
		ss = o.subsection;
		if (has_sysupgrade) {
			o = ss.option(form.Button, 'sysupgrade', _('Image'));
			o.inputstyle = 'action important';
			o.inputtitle = _('Flash image...');
			o.onclick = L.bind(this.handleSysupgrade, this, storage_size, has_rootfs_data);
		}

		return m.render();
	},

	handleSaveApply: null,
	handleSave: null,
	handleReset: null
});
EOF
    echo "✅ تم تخصيص ملف flash.js بنجاح."
fi

# ==========================================
# 11. تخصيص الفوتر (Footer) لثيم Argon (Promax-NEt)
# ==========================================
for FOOTER_FILE in \
    "package/luci-theme-argon/luasrc/view/themes/argon/footer.htm" \
    "feeds/luci/themes/luci-theme-argon/luasrc/view/themes/argon/footer.htm"
do
    if [ -f "$FOOTER_FILE" ]; then
        cat << 'EOF' > "$FOOTER_FILE"
<%#
 Argon theme footer
-%>
</div>
<footer class="mobile-hide" style="text-wrap: auto">
	<div class="footer-content" style="display: flex; flex-wrap: wrap; gap: 0.5em; justify-content: end;">
		<span style="color: #5e72e4; font-weight: 500;">Powered by Promax-NEt</span>
	</div>
</footer>
</main>
</div>
</div>
</body>
</html>
EOF
        echo "✅ تم تخصيص $FOOTER_FILE بنجاح."
    fi
done

# ==========================================
# 12. تفعيل حزمة wpad لتشغيل الواي فاي ومنع تعارض حزم wpad الأخرى
# ==========================================
if [ -f .config ]; then
    sed -i "/CONFIG_PACKAGE_wpad/d" .config
    cat << 'EOF' >> .config
# CONFIG_PACKAGE_wpad-basic is not set
# CONFIG_PACKAGE_wpad-basic-wolfssl is not set
# CONFIG_PACKAGE_wpad-basic-mbedtls is not set
# CONFIG_PACKAGE_wpad-mini is not set
# CONFIG_PACKAGE_wpad-mesh-wolfssl is not set
# CONFIG_PACKAGE_wpad-mesh-mbedtls is not set
# CONFIG_PACKAGE_wpad-mbedtls is not set
# CONFIG_PACKAGE_wpad-wolfssl is not set
# CONFIG_PACKAGE_wpad-openssl is not set
CONFIG_PACKAGE_wpad=y
EOF
    echo "✅ تم ضبط حزمة wpad لتشغيل الواي فاي ومنع التعارض."
fi

# ==========================================
# 13. ضبط مستودعات opkg على HTTP لتفادي أخطاء شهادة TLS
# ==========================================
cat << 'EOF' > package/base-files/files/etc/uci-defaults/96-fix-opkg-http
#!/bin/sh
if [ -f /etc/opkg/distfeeds.conf ]; then
    sed -i "s|https://|http://|g" /etc/opkg/distfeeds.conf
fi
exit 0
EOF
chmod +x package/base-files/files/etc/uci-defaults/96-fix-opkg-http

# ==========================================
# 14. إخفاء تبويب Argon Config وتبويب Software من قائمة LuCI نهائياً
# ==========================================
for MENU_FILE in $(find feeds/luci package -path "*/root/usr/share/luci/menu.d/*.json" 2>/dev/null); do
    case "$(basename "$MENU_FILE")" in
        *argon*config*.json|*opkg*.json|*packages*.json)
            rm -f "$MENU_FILE"
            echo "✅ تم حذف ملف قائمة: $MENU_FILE"
            continue
            ;;
    esac
    if grep -qE "admin/system/opkg|admin/system/packages|admin/system/argon|admin/system/argon-config" "$MENU_FILE"; then
        awk '
        /"admin\/system\/admin\/opkg":/ || /"admin\/system\/admin\/packages":/ || /"admin\/system\/admin\/argon":/ || /"admin\/system\/admin\/argon-config":/ { skip=1; braces=0 }
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
        ' "$MENU_FILE" > "$MENU_FILE.tmp" && mv "$MENU_FILE.tmp" "$MENU_FILE"

        sed -i ":a;N;\$!ba;s/,\s*\n\s*}/\n}/g" "$MENU_FILE" 2>/dev/null || true
        echo "✅ تم إخفاء العناصر المستهدفة من: $MENU_FILE"
    fi
done

# ==========================================
# 15. دمج إضافة quicksetup_backup.tar.gz داخل الفيرموير
# ==========================================
mkdir -p package/base-files/files
if [ -n "$GITHUB_WORKSPACE" ] && [ -f "$GITHUB_WORKSPACE/quicksetup_backup.tar.gz" ]; then
    tar -xzf "$GITHUB_WORKSPACE/quicksetup_backup.tar.gz" -C package/base-files/files/
    chmod +x package/base-files/files/etc/init.d/wizard 2>/dev/null || true

    cat << 'EOF' > package/base-files/files/etc/uci-defaults/95-enable-quicksetup
#!/bin/sh
if [ -x /etc/init.d/wizard ]; then
    /etc/init.d/wizard enable >/dev/null 2>&1 || true
    /etc/init.d/wizard start >/dev/null 2>&1 || true
fi
rm -rf /tmp/luci-indexcache /tmp/luci-modulecache
exit 0
EOF
    chmod +x package/base-files/files/etc/uci-defaults/95-enable-quicksetup
    echo "✅ تم دمج إضافة quicksetup وتفعيل خدمة wizard بنجاح."
else
    echo "⚠️ تحذير: لم يتم العثور على ملف quicksetup_backup.tar.gz في المستودع."
fi

# ==========================================
# 16. تسلسل إضاءة LEDs عند الإقلاع والاستقرار وضبط المؤشرات
# ==========================================
mkdir -p package/base-files/files/usr/bin
cat << 'EOF' > package/base-files/files/usr/bin/promax-led-boot.sh
#!/bin/sh

LED_Y1="yellow:sys"
LED_Y2="yellow:net"
LED_B1="blue:sys"
LED_B2="blue:net"

max_val() {
    local led="$1"
    if [ -f "/sys/class/leds/$led/max_brightness" ]; then
        cat "/sys/class/leds/$led/max_brightness"
    else
        echo 255
    fi
}

set_led() {
    local led="$1"
    local trig="$2"
    local val="$3"
    [ -d "/sys/class/leds/$led" ] || return 0
    if [ -n "$trig" ] && [ -f "/sys/class/leds/$led/trigger" ]; then
        echo "$trig" > "/sys/class/leds/$led/trigger" 2>/dev/null || true
    fi
    if [ -n "$val" ] && [ -f "/sys/class/leds/$led/brightness" ]; then
        echo "$val" > "/sys/class/leds/$led/brightness" 2>/dev/null || true
    fi
}

(
    sleep 3
    VY1=$(max_val "$LED_Y1")
    VY2=$(max_val "$LED_Y2")
    VB1=$(max_val "$LED_B1")

    set_led "$LED_B1" "none" 0
    set_led "$LED_B2" "none" 0
    set_led "$LED_Y1" "none" 0
    set_led "$LED_Y2" "none" 0

    set_led "$LED_Y1" "none" "$VY1"
    sleep 3

    set_led "$LED_Y1" "none" 0
    set_led "$LED_Y2" "none" 0
    i=0
    while [ $i -lt 8 ]; do
        echo "$VY1" > "/sys/class/leds/$LED_Y1/brightness" 2>/dev/null || true
        echo "$VY2" > "/sys/class/leds/$LED_Y2/brightness" 2>/dev/null || true
        sleep 0.35
        echo 0 > "/sys/class/leds/$LED_Y1/brightness" 2>/dev/null || true
        echo 0 > "/sys/class/leds/$LED_Y2/brightness" 2>/dev/null || true
        sleep 0.35
        i=$((i + 1))
    done

    set_led "$LED_Y1" "none" 0
    set_led "$LED_Y2" "none" 0
    set_led "$LED_B1" "default-on" "$VB1"
    if [ ! -f "/sys/class/leds/$LED_B1/trigger" ]; then
        echo "$VB1" > "/sys/class/leds/$LED_B1/brightness" 2>/dev/null || true
    fi

    if [ -d "/sys/class/leds/$LED_B2" ] && [ -f "/sys/class/leds/$LED_B2/trigger" ]; then
        echo "netdev" > "/sys/class/leds/$LED_B2/trigger" 2>/dev/null || true
        [ -f "/sys/class/leds/$LED_B2/device_name" ] && echo "br-lan" > "/sys/class/leds/$LED_B2/device_name" 2>/dev/null || true
        [ -f "/sys/class/leds/$LED_B2/link" ] && echo 1 > "/sys/class/leds/$LED_B2/link" 2>/dev/null || true
        [ -f "/sys/class/leds/$LED_B2/tx" ] && echo 1 > "/sys/class/leds/$LED_B2/tx" 2>/dev/null || true
        [ -f "/sys/class/leds/$LED_B2/rx" ] && echo 1 > "/sys/class/leds/$LED_B2/rx" 2>/dev/null || true
    fi
) >/dev/null 2>&1 &
exit 0
EOF
chmod +x package/base-files/files/usr/bin/promax-led-boot.sh

if [ -f package/base-files/files/etc/rc.local ]; then
    if ! grep -q "promax-led-boot.sh" package/base-files/files/etc/rc.local; then
        sed -i "/exit 0/i /usr/bin/promax-led-boot.sh" package/base-files/files/etc/rc.local
    fi
fi
echo "✅ تم إعداد تسلسل LEDs عند الإقلاع بنجاح."

# ==========================================
# 17. إزالة علامة الصح من Enable NTP client وحذف إدخالات NTP server candidates
# ==========================================
cat << 'EOF' > package/base-files/files/etc/uci-defaults/94-promax-ntp-clean
#!/bin/sh
uci -q set system.ntp.enabled='0'
uci -q delete system.ntp.server
uci commit system
/etc/init.d/sysntpd reload 2>/dev/null || true
exit 0
EOF
chmod +x package/base-files/files/etc/uci-defaults/94-promax-ntp-clean
echo "✅ تم إعداد تعطيل NTP client وحذف NTP server candidates."

# ==========================================
# 18. جعل زر WPS (و Mesh) يقوم بعمل فورمات (10s+) وتعطيل زر Reset الخلفي (بدون تعارض مع hostapd-common)
# ==========================================
rm -f package/base-files/files/etc/rc.button/wps \
      package/base-files/files/etc/rc.button/mesh \
      files/etc/rc.button/wps \
      files/etc/rc.button/mesh

mkdir -p package/base-files/files/usr/bin package/base-files/files/etc/uci-defaults package/base-files/files/etc/rc.button files/etc/rc.button

cat << 'EOF' > package/base-files/files/usr/bin/promax-wps-reset.sh
#!/bin/sh

. /lib/functions.sh

logger "$BUTTON pressed for $SEEN seconds"

if [ "$ACTION" = "released" ]; then
    if [ "$SEEN" -ge 10 ]; then
        echo "FACTORY RESET via front button ($BUTTON) after ${SEEN}s" > /dev/console
        jffs2reset -y && reboot &
    fi
fi

return 0
EOF
chmod +x package/base-files/files/usr/bin/promax-wps-reset.sh

cat << 'EOF' > package/base-files/files/etc/rc.button/reset
#!/bin/sh

. /lib/functions.sh

logger "Rear reset button ($BUTTON) is disabled"
return 0
EOF
chmod +x package/base-files/files/etc/rc.button/reset

cat << 'EOF' > package/base-files/files/etc/uci-defaults/92-promax-buttons
#!/bin/sh
mkdir -p /etc/rc.button

cat << 'BTN' > /etc/rc.button/wps
#!/bin/sh
exec /usr/bin/promax-wps-reset.sh
BTN
chmod +x /etc/rc.button/wps

cp -f /etc/rc.button/wps /etc/rc.button/mesh
chmod +x /etc/rc.button/mesh
exit 0
EOF
chmod +x package/base-files/files/etc/uci-defaults/92-promax-buttons

cp -f package/base-files/files/etc/rc.button/reset files/etc/rc.button/reset 2>/dev/null || true
chmod +x files/etc/rc.button/reset 2>/dev/null || true

echo "✅ تم إعداد زر WPS للفرمتة (10 ثوانٍ+) وتعطيل زر reset الخلفي بدون تعارض مع hostapd-common."
