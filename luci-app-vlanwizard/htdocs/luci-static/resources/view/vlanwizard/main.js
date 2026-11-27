'use strict';
'require view';
'require form';
'require uci';
'require fs';
'require ui';

return view.extend({
load: function() {
// قراءة القيم المباشرة من النظام وتحديث ملف الويزارد لحظياً قبل العرض
return Promise.all([
fs.exec_direct('/bin/sh', ['-c', "uci -q get wireless.ap_2g.ssid || echo 'AL-Sarie 2025'"]),
fs.exec_direct('/bin/sh', ['-c', "uci -q get wireless.mesh.mesh_id || echo 'Mesh50'"]),
fs.exec_direct('/bin/sh', ['-c', "uci -q get network.lan.ipaddr || echo '192.168.2.125'"]),
fs.exec_direct('/bin/sh', ['-c', "for d in $(uci show network 2>/dev/null | grep \"\\.type='8021q'\" | cut -d. -f2); do v=$(uci -q get network.$d.vid); [ -n \"$v\" ] && { echo $v; break; }; done"])
]).then(function(res) {
var ssid = res[0].trim();
var mesh = res[1].trim();
var ip = res[2].trim();
var vlan = res[3].trim();

if (ssid) uci.set('wizard', 'default', 'SSID2G', ssid);
if (mesh) uci.set('wizard', 'default', 'MESHID', mesh);
if (ip)   uci.set('wizard', 'default', 'IPADD', ip);
if (vlan) uci.set('wizard', 'default', 'VLANID', vlan);

return uci.load('wizard');
}).catch(function(e) {
return uci.load('wizard');
});
},

render: function() {
var m, s, o;

var btnBar = E('div', {
'style': 'display:flex;gap:10px;margin-bottom:15px;flex-wrap:wrap;'
}, [
E('button', {
'class': 'btn cbi-button cbi-button-apply',
'style': 'background:#0056b3;color:#0450a2;font-weight:bold;padding:10px 20px;',
'click': ui.createHandlerFn(this, 'applyAll')
}, '🚀 تطبيق الآن')
]);

m = new form.Map('wizard', _('البرمجة السريعة'),
_('تم جلب إعدادات الجهاز الحالية تلقائياً. قم بتعديل ما تحتاجه ثم اضغط "تطبيق الآن"'));

s = m.section(form.NamedSection, 'default', 'wizard');
s.addremove = false;

s.tab('MkSetup', _('إعدادات الجهاز'));

o = s.taboption('MkSetup', form.ListValue, 'MKSettings', _('وضع البرمجة : '));
o.rmempty = false;
o.value('APVL',    _('AP برمجة أكسس + فيلان'));
o.value('APMVL',   _('MESH برمجة مش + فيلان'));
o.value('APWDSVL', _('WDS برمجة مرسل + فيلان'));
o.value('STWDSVL', _('WDS برمجة مستقبل + فيلان'));
o.value('AP',      _('AP برمجة أكسس'));
o.value('APM',     _('MESH برمجة مش'));
o.value('APWDS',   _('WDS برمجة مرسل'));
o.value('STWDS',   _('WDS برمجة مستقبل'));
o.value('APPPP',   _('اكسس بوينت برودباند'));
o.default = 'APMVL';

o = s.taboption('MkSetup', form.Value, 'IPADD', _('عنوان الأيبي : '));
o.datatype = 'ip4addr';
o.default = '192.168.2.125';
o.rmempty = false;

o = s.taboption('MkSetup', form.Value, 'PPPUSER', _('PAP/CHAP إسم المستخدم : '));
o.depends('MKSettings', 'APPPP');

o = s.taboption('MkSetup', form.Value, 'PPPPASS', _('PAP/CHAP كلمة السر : '));
o.depends('MKSettings', 'APPPP');
o.password = true;

o = s.taboption('MkSetup', form.ListValue, 'PPPINTERFACE', _('منفذ البرودباند : '));
o.depends('MKSettings', 'APPPP');
o.value('wan',    _('Switch port: wan'));
o.value('lan1',   _('Switch port: lan1'));
o.value('lan2',   _('Switch port: lan2'));
o.value('lan3',   _('Switch port: lan3'));
o.value('lan4',   _('Switch port: lan4'));
o.value('br-lan', _('Bridge: br-lan'));
o.value('eth0',   _('Ethernet: eth0'));
o.default = 'wan';

o = s.taboption('MkSetup', form.Value, 'VLANID', _('رقم الفيلان : '));
o.depends('MKSettings', 'APVL');
o.depends('MKSettings', 'APMVL');
o.depends('MKSettings', 'APWDSVL');
o.depends('MKSettings', 'STWDSVL');
o.datatype = 'range(1, 4094)';
o.default = '2025';

o = s.taboption('MkSetup', form.Value, 'SSID2G', _('إسم شبكة البث : '));
o.datatype = 'maxlength(32)';
o.default = 'AL-Sarie 2025';
o.rmempty = false;

o = s.taboption('MkSetup', form.ListValue, 'CH2G', _('2.4G قناة : '));
o.value('auto', _('تلقائي'));
for (var i = 1; i <= 13; i++) o.value(String(i), String(i));
o.default = 'auto';

o = s.taboption('MkSetup', form.Value, 'MESHID', _('عنوان المش : '));
o.depends('MKSettings', 'APMVL');
o.depends('MKSettings', 'APM');
o.default = 'Mesh50';

o = s.taboption('MkSetup', form.Value, 'APWDSSID', _('أسم المرسل WDS : '));
o.depends('MKSettings', 'APWDSVL');
o.depends('MKSettings', 'APWDS');
o.default = 'APWDS50';

o = s.taboption('MkSetup', form.Value, 'STAWDSSID', _('أسم المستقبل WDS : '));
o.depends('MKSettings', 'STWDSVL');
o.depends('MKSettings', 'STWDS');
o.default = 'APWDS50';

o = s.taboption('MkSetup', form.Flag, 'HIDDEN', _('إخفاء البث : '));
o.depends('MKSettings', 'APWDSVL');
o.depends('MKSettings', 'APWDS');

o = s.taboption('MkSetup', form.ListValue, 'CH5G', _('5G قناة : '));
o.value('auto', _('تلقائي'));
var ch5 = [36,40,44,48,52,56,60,64,100,104,108,112,116,120,124,128,132,136,140,144,149,153,157,161,165];
for (var j = 0; j < ch5.length; j++) o.value(String(ch5[j]), String(ch5[j]));
o.default = '36';

o = s.taboption('MkSetup', form.ListValue, 'WKEYTYPE', _('نوع الحماية : '));
o.value('none', _('مفتوح'));
o.value('psk',  _('WPA-PSK'));
o.value('psk2', _('WPA2-PSK'));
o.value('sae',  _('WPA3-SAE'));
o.default = 'none';

o = s.taboption('MkSetup', form.Value, 'WIFIKEY', _('كلمة السر : '));
o.depends('WKEYTYPE', 'psk');
o.depends('WKEYTYPE', 'psk2');
o.depends('WKEYTYPE', 'sae');
o.password = true;

o = s.taboption('MkSetup', form.Flag, 'DoPASS', _('تغيير كلمة مرور الجهاز : '));

o = s.taboption('MkSetup', form.Value, 'DPASS', _('كلمة السر الجديدة : '));
o.depends('DoPASS', '1');
o.password = true;

o = s.taboption('MkSetup', form.Flag, 'RmoveOldConfig', _('حذف الإعدادات السابقة : '));
o.default = '1';

s.tab('MkSecurity', _('إعدادات الحماية'));

o = s.taboption('MkSecurity', form.Flag, 'STOPREST', _('إيقاف زر الفورمات : '));
o.default = '0';

o = s.taboption('MkSecurity', form.Flag, 'TYPREST', _('تخصيص طريقة الفورمات : '));
o.depends('STOPREST', '0');
o.default = '0';

o = s.taboption('MkSecurity', form.Value, 'DelayREST', _('مدة الضغط على الزر (ثواني) : '));
o.depends('TYPREST', '1');
o.default = '30';
o.datatype = 'range(5, 600)';

s.tab('MkAdvance', _('إعدادات متقدمة'));

o = s.taboption('MkAdvance', form.ListValue, 'CHWidte', _('طاقة البث : '));
o.value('auto',  _('الإفتراضي'));
o.value('RANG0', _('رفع بسيط 2dBm'));
o.value('RANG1', _('رفع متوسط 4dBm'));
o.value('RANG2', _('رفع قوي 6dBm'));
o.default = 'auto';

o = s.taboption('MkAdvance', form.Flag, 'NO_NAT', _('إلغاء NAT : '));
o.default = '0';

o = s.taboption('MkAdvance', form.Flag, 'dhcpServer', _('إيقاف DHCP Server : '));
o.default = '0';

o = s.taboption('MkAdvance', form.Flag, 'NO_Firewall', _('إلغاء جدار الحماية : '));
o.default = '0';

o = s.taboption('MkAdvance', form.Flag, 'No_WatchCat', _('إعادة التشغيل التلقائي : '));
o.default = '0';

o = s.taboption('MkAdvance', form.ListValue, 'WC_Preiod', _('فترة WatchCat : '));
o.depends('No_WatchCat', '1');
o.value('3h',     _('كل 3 ساعات'));
o.value('6h',     _('كل 6 ساعات'));
o.value('12h',    _('كل 12 ساعة'));
o.value('custom', _('مخصص'));
o.default = '3h';

o = s.taboption('MkAdvance', form.Value, 'WC_Timer', _('الفترة بالدقائق : '));
o.depends('WC_Preiod', 'custom');
o.default = '180';
o.datatype = 'range(5, 1440)';

o = s.taboption('MkAdvance', form.Flag, 'NO_PPPOE', _('إلغاء PPPoE : '));
o.default, '0';

o = s.taboption('MkAdvance', form.Flag, 'NO_FAKE', _('Fake Mesh : '));
o.default = '0';

this._formMap = m;

return m.render().then(function(mapEl) {
return E('div', {}, [btnBar, mapEl]);
});
},

applyAll: function() {
var self = this;

ui.showModal(_('تطبيق الآن'), [
E('p', {}, _('جاري حفظ الإعدادات وتنفيذها...')),
E('div', { 'class': 'spinning' })
]);

var savePromise;
try {
savePromise = this._formMap.save();
} catch(e) {
savePromise = Promise.resolve();
}

return Promise.resolve(savePromise)
.then(function() { return uci.save(); })
.then(function() { return uci.apply(); })
.then(function() {
return fs.exec('/etc/init.d/wizard', ['start']);
})
.then(function(res) {
ui.hideModal();
if (res && res.code === 0) {
ui.addNotification(null,
E('p', {}, '✅ تم التطبيق بنجاح! ستُعاد الشبكة خلال لحظات...'),
'info');
setTimeout(function() { window.location.reload(); }, 12000);
} else {
ui.addNotification(null,
E('p', {}, '⚠️ خطأ: ' + (res ? res.code : '?')),
'error');
}
})
.catch(function(e) {
ui.hideModal();
ui.addNotification(null, E('p', {}, '❌ ' + (e.message || e)), 'error');
});
},

handleSave: null,
handleSaveApply: null,
handleReset: null
});
