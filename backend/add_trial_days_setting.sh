#!/usr/bin/env bash
#
# add_trial_days_setting.sh — a trial-days field in the admin settings page.
#
# trial_days lives in platform_settings and signup reads it, but there is nowhere to set it
# except psql. This adds it beside the commission rate and per-user fee, using the same
# GET/POST /admin/settings pattern those already use rather than a second mechanism.
#
set -uo pipefail
BE=/var/www/rumalink/backend
D=/var/www/rumalink/admin/dashboard.html
TS=$(date +%s)
G=$'\e[32m'; Y=$'\e[33m'; N=$'\e[0m'
say(){ echo; echo "${G}===== $* =====${N}"; }
q(){ sudo -u postgres psql -d rumalink_db -P pager=off "$@" 2>&1; }

say "1) The settings route as it stands"
sudo sed -n '676,712p' "$BE/routes/admin.js" | nl -ba -v676 | sed 's/^/   /'

say "2) Backups"
sudo cp "$BE/routes/admin.js" "$BE/routes/.admin.js.bak_$TS" && echo "   admin.js"
sudo cp "$D" "/var/www/rumalink/admin/.dashboard.html.bak_$TS" && echo "   admin/dashboard.html"

say "3) Include trial_days in the settings read and write"
sudo python3 - "$BE/routes/admin.js" <<'PY'
import sys, re
p=sys.argv[1]; s=open(p).read()
if 'RL_TRIAL_DAYS_SETTING' in s:
    print("   already patched"); sys.exit(0)
n = 0

old_r = "const r = await query(\"SELECT key, value FROM platform_settings WHERE key IN ('hotspot_commission_rate','pppoe_per_user_fee')\");"
new_r = ("/* RL_TRIAL_DAYS_SETTING: read alongside the rates so the settings page has one source. */\n"
         "    const r = await query(\"SELECT key, value FROM platform_settings WHERE key IN ('hotspot_commission_rate','pppoe_per_user_fee','trial_days')\");")
if old_r in s: s = s.replace(old_r, new_r, 1); n += 1
else: print("   MISS: settings read")

m = re.search(r'^([ \t]*)await query\(`INSERT INTO platform_settings \(key, value, updated_at\) VALUES \(.pppoe_per_user_fee.,\$1,NOW\(\)\)[\s\S]*?\);', s, re.M)
if m:
    ind = m.group(1)
    add = ("\n\n" + ind + "/* RL_TRIAL_DAYS_SETTING: free days a new ISP gets before billing begins. Signup reads this\n"
           + ind + "   at INSERT time, so a change here applies to ISPs created afterwards — existing trials keep\n"
           + ind + "   the length they were given, which is the honest behaviour for an account already running. */\n"
           + ind + "if (req.body.trial_days !== undefined && req.body.trial_days !== null && req.body.trial_days !== '') {\n"
           + ind + "  const _td = parseInt(req.body.trial_days, 10);\n"
           + ind + "  if (Number.isFinite(_td) && _td >= 0 && _td <= 365) {\n"
           + ind + "    await query(`INSERT INTO platform_settings (key, value, updated_at) VALUES ('trial_days',$1,NOW())\n"
           + ind + "                 ON CONFLICT (key) DO UPDATE SET value=$1, updated_at=NOW()`, [_td]);\n"
           + ind + "  } else {\n"
           + ind + "    return res.status(400).json({ error: 'Trial days must be a whole number between 0 and 365' });\n"
           + ind + "  }\n"
           + ind + "}")
    s = s[:m.end()] + add + s[m.end():]
    n += 1
else:
    print("   MISS: settings write block")
open(p,'w').write(s); print(f"   {n}/2 change(s) applied")
PY
cd "$BE" && sudo -u www-data node --check routes/admin.js && echo "   admin.js OK"

say "4) Add the field to the settings page"
sudo python3 - "$D" <<'PY'
import sys, re
p=sys.argv[1]; s=open(p).read()
if 'set-trial-days' in s:
    print("   already present"); sys.exit(0)
m = re.search(r'(<[^>]*id="set-pppoe-rate"[^>]*>)', s)
if not m:
    print("   ERROR: pppoe rate input not found"); sys.exit(1)
line_start = s.rfind('<', 0, m.start())
block_start = s.rfind('<div', 0, m.start())
block_end = s.find('</div>', m.end())
if block_start == -1 or block_end == -1:
    print("   ERROR: could not locate the surrounding field"); sys.exit(1)
block = s[block_start:block_end+6]
field = block.replace('set-pppoe-rate', 'set-trial-days')
field = re.sub(r'>([^<>]*(?:Fee|fee|PPPoE)[^<>]*)<', '>Free trial (days)<', field, count=1)
field = re.sub(r'placeholder="[^"]*"', 'placeholder="3"', field)
field = re.sub(r'value="[^"]*"', '', field)
s = s[:block_end+6] + '\n        ' + field + s[block_end+6:]
open(p,'w').write(s); print("   field added next to the per-user fee")
PY

say "5) Load and save it with the others"
sudo python3 - "$D" <<'PY'
import sys, re
p=sys.argv[1]; s=open(p).read()
if 'RL_TRIAL_DAYS_UI' in s:
    print("   already patched"); sys.exit(0)
n = 0
old_save = "      pppoe_per_user_fee: pppoe"
new_save = ("      pppoe_per_user_fee: pppoe,\n"
            "      /* RL_TRIAL_DAYS_UI: applies to ISPs created after the change; running trials keep theirs */\n"
            "      trial_days: (document.getElementById('set-trial-days') || {}).value")
if old_save in s: s = s.replace(old_save, new_save, 1); n += 1
else: print("   MISS: save payload")

old_load = "    document.getElementById('set-pppoe-rate').value = (d.pppoe_per_user_fee != null) ? d.pppoe_per_user_fee : 32.25;"
new_load = (old_load + "\n"
            "    { const _t = document.getElementById('set-trial-days');\n"
            "      if (_t) _t.value = (d.trial_days != null) ? d.trial_days : 3; } /* RL_TRIAL_DAYS_UI */")
if old_load in s: s = s.replace(old_load, new_load, 1); n += 1
else: print("   MISS: load block")
open(p,'w').write(s); print(f"   {n}/2 wired")
PY
sudo chown www-data:www-data "$D"
echo "   div balance: $(( $(grep -o '<div' "$D" | wc -l) - $(grep -o '</div>' "$D" | wc -l) ))"
echo "   script pairs: $(grep -o '<script' "$D" | wc -l) / $(grep -o '</script>' "$D" | wc -l)"
grep -c "set-trial-days" "$D" | sed 's/^/   set-trial-days references: /'

say "6) Restart + verify"
sudo pm2 restart rumalink-backend --update-env >/dev/null 2>&1; sleep 8
q -c "SELECT key, value, updated_at FROM platform_settings ORDER BY key;"
pm2 logs rumalink-backend --lines 15 --nostream 2>/dev/null | grep -iE "error" | tail -3 | sed 's/^/   /' || echo "   clean"

say "7) Check"
cat <<'EOS'
   Open admin settings — "Free trial (days)" sits beside the PPPoE per-user fee. Change it, save,
   and confirm it persists:
     sudo -u postgres psql -d rumalink_db -c "SELECT key, value FROM platform_settings WHERE key='trial_days';"

   It applies to ISPs signing up AFTER the change. An account already in its trial keeps the
   length it was given — retroactively shortening a running trial would bill someone for days
   they were told were free.
EOS

say "8) Commit"
sudo git -C /var/www/rumalink add -A 2>/dev/null
sudo git -C /var/www/rumalink commit -qm "Admin settings: editable free-trial length" 2>&1 | head -2 | sed 's/^/   /'
