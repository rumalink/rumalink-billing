#!/usr/bin/env bash
#
# fix_pppoe_sms.sh — PPPoE customers get no SMS on renewal or expiry.
#
# CAUSE 1 (expiry, welcome): both are gated on the ISP's sms_gateway COLUMN being set —
#   cron.js:688  `if (sub.phone && sub.sms_gateway)`
#   pppoe.js:162 `if (isp.rows[0]?.sms_gateway)`
#   That column is blank for every ISP on the platform gateway; sendSMS defaults it to
#   'rumalink' internally, which is why hotspot SMS works. Checking the column before calling
#   skips the send entirely, silently.
#
# CAUSE 2 (renewal): onPaid extends billing, restores access and credits the wallet, but never
#   notifies the subscriber at all — there is no send to add a gate to.
#
set -uo pipefail
BE=/var/www/rumalink/backend
TS=$(date +%s)
G=$'\e[32m'; Y=$'\e[33m'; N=$'\e[0m'
say(){ echo; echo "${G}===== $* =====${N}"; }
q(){ sudo -u postgres psql -d rumalink_db -P pager=off "$@" 2>&1; }

say "0) Backups"
for f in utils/cron.js routes/pppoe.js routes/pppoePortal.js; do
  sudo cp "$BE/$f" "$BE/$(dirname $f)/.$(basename $f).bak_$TS" && echo "   $f"
done

say "1) Expiry SMS — stop gating on the empty sms_gateway column"
sudo python3 - "$BE/utils/cron.js" <<'PY'
import sys, re
p=sys.argv[1]; s=open(p).read()
if 'RL_PPPOE_SMS_GATE' in s:
    print("   already patched"); sys.exit(0)
m = re.search(r'^([ \t]*)if \(sub\.phone && sub\.sms_gateway\) \{', s, re.M)
if not m:
    print("   ERROR: expiry gate not found"); sys.exit(1)
ind = m.group(1)
new = (f"{ind}/* RL_PPPOE_SMS_GATE: this required isps.sms_gateway to be SET. It is blank for every ISP\n"
       f"{ind}   using the platform gateway — sendSMS defaults it to 'rumalink' internally — so the\n"
       f"{ind}   expiry notice was skipped silently while hotspot SMS worked fine. Send whenever the\n"
       f"{ind}   subscriber has a phone; sendSMS decides the gateway. */\n"
       f"{ind}if (sub.phone) {{")
s = s[:m.start()] + new + s[m.end():]
open(p,'w').write(s); print("   expiry SMS gate removed")
PY
cd "$BE" && sudo -u www-data node --check utils/cron.js && echo "   cron.js syntax OK"

say "2) Welcome SMS — same gate in pppoe.js"
sudo python3 - "$BE/routes/pppoe.js" <<'PY'
import sys, re
p=sys.argv[1]; s=open(p).read()
if 'RL_PPPOE_WELCOME_GATE' in s:
    print("   already patched"); sys.exit(0)
m = re.search(r'^([ \t]*)if \(isp\.rows\[0\]\?\.sms_gateway\) \{', s, re.M)
if not m:
    print("   gate not found (already fixed?)"); sys.exit(0)
ind = m.group(1)
new = (f"{ind}/* RL_PPPOE_WELCOME_GATE: gated on the sms_gateway column, which is blank on the platform\n"
       f"{ind}   gateway — the welcome SMS never sent. sendSMS resolves the gateway itself. */\n"
       f"{ind}if (isp.rows[0]) {{")
s = s[:m.start()] + new + s[m.end():]
open(p,'w').write(s); print("   welcome SMS gate removed")
PY
cd "$BE" && sudo -u www-data node --check routes/pppoe.js && echo "   pppoe.js syntax OK"

say "3) Renewal confirmation — add it to onPaid"
sudo python3 - "$BE/routes/pppoePortal.js" <<'PY'
import sys, re
p=sys.argv[1]; s=open(p).read()
if 'RL_PPPOE_RENEWAL_SMS' in s:
    print("   already patched"); sys.exit(0)
m = re.search(r"^([ \t]*)catch\(e\)\{ logger\.error\('\[PPPoE-portal\] wallet credit: '\+e\.message\); \}", s, re.M)
if not m:
    print("   ERROR: wallet-credit anchor not found"); sys.exit(1)
ind = m.group(1)
add = (
f"\n{ind}/* RL_PPPOE_RENEWAL_SMS: onPaid extended the billing date, restored access and credited the\n"
f"{ind}   wallet, but never told the customer their plan was renewed — the one party who paid heard\n"
f"{ind}   nothing. Idempotent via the payment's own flag, so the Daraja callback, the IntaSend IPN\n"
f"{ind}   and the sweep cannot each send their own copy of the same renewal. */\n"
f"{ind}try {{\n"
f"{ind}  const _sent = (pay.metadata && (typeof pay.metadata === 'string' ? JSON.parse(pay.metadata) : pay.metadata) || {{}}).rl_renewal_sms;\n"
f"{ind}  if (!_sent && sub.phone) {{\n"
f"{ind}    const _info = (await query(\n"
f"{ind}      'SELECT pp.name AS pkg_name, pp.price, i.company_name, i.* FROM pppoe_subscribers ps ' +\n"
f"{ind}      'JOIN pppoe_packages pp ON pp.id=ps.package_id JOIN isps i ON i.id=ps.isp_id ' +\n"
f"{ind}      'WHERE ps.id=$1::uuid LIMIT 1', [sub.id])).rows[0];\n"
f"{ind}    if (_info) {{\n"
f"{ind}      const _due = new Date(nb).toLocaleDateString('en-KE', {{ day:'numeric', month:'short', year:'numeric' }});\n"
f"{ind}      await require('../utils/sms').sendSMS({{\n"
f"{ind}        to: sub.phone,\n"
f"{ind}        message: 'Dear ' + (sub.full_name || 'Customer') + ', your ' + _info.company_name +\n"
f"{ind}                 ' internet (' + _info.pkg_name + ') has been RENEWED. You are back online. ' +\n"
f"{ind}                 'Next due: ' + _due + '. Thank you!',\n"
f"{ind}        isp: _info\n"
f"{ind}      }});\n"
f"{ind}      await query(\"UPDATE payments SET metadata = COALESCE(metadata,'{{}}'::jsonb) || jsonb_build_object('rl_renewal_sms','sent') WHERE id=$1::uuid\", [paymentId]).catch(function(){{}});\n"
f"{ind}      await query('UPDATE pppoe_subscribers SET payment_sms_sent_at=NOW() WHERE id=$1::uuid', [sub.id]).catch(function(){{}});\n"
f"{ind}      logger.info('[PPPoE-portal] renewal SMS sent to ' + sub.phone + ' for ' + sub.username);\n"
f"{ind}    }}\n"
f"{ind}  }}\n"
f"{ind}}} catch(e) {{ logger.error('[PPPoE-portal] renewal sms: ' + e.message); }}"
)
s = s[:m.end()] + add + s[m.end():]
open(p,'w').write(s); print("   renewal SMS added to onPaid")
PY
cd "$BE" && sudo -u www-data node --check routes/pppoePortal.js && echo "   pppoePortal.js syntax OK"

say "4) Restart"
sudo pm2 restart rumalink-backend --update-env >/dev/null 2>&1; sleep 8
pm2 logs rumalink-backend --lines 20 --nostream 2>/dev/null | grep -iE "error" | tail -3 | sed 's/^/   /' || echo "   clean"

say "5) The expired subscriber should now get the expiry SMS within a minute"
q -c "SELECT username, full_name, phone, status, next_billing_date FROM pppoe_subscribers;"
echo "   waiting 70s for the per-minute expiry sweep..."
sleep 70
pm2 logs rumalink-backend --lines 60 --nostream 2>/dev/null | grep -iE "expiry-enforcer|renewal sms|SMS sent" | tail -6 | sed 's/^/   /' || echo "   (no expiry SMS — the subscriber may already be walled from an earlier pass)"
q -c "SELECT recipient, LEFT(message,52) AS msg, to_char(sent_at,'HH24:MI:SS') AS at FROM sms_logs ORDER BY sent_at DESC LIMIT 4;"

say "6) What PPPoE subscribers now receive"
cat <<'EOS'
   welcome        when the ISP creates them            (gate removed)
   3-day / 1-day  billing reminders                    (already worked)
   expiry         the minute their plan lapses         (gate removed)
   RENEWED        as soon as their payment completes   (new)
   All go to pppoe_subscribers.phone; the ISP's own alerts go to isps.phone.
EOS

say "7) Commit"
sudo git -C /var/www/rumalink add -A 2>/dev/null
sudo git -C /var/www/rumalink commit -qm "PPPoE: renewal SMS added; expiry and welcome no longer gated on an empty sms_gateway column" 2>&1 | head -2 | sed 's/^/   /'
