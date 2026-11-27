module("luci.controller.vlanwizard", package.seeall)

function index()
    entry({"admin", "vlanwizard"},
          view("vlanwizard/main"),
          _("البرمجة السريعة"),
          45).dependent = false
end
