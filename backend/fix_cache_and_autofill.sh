#!/usr/bin/env bash
#
# fix_cache_and_autofill.sh
#  1. The Actions column IS in the file the server holds — header at line 583, cell in renderRows.
#     The browser is showing a cached copy. Confirm what the server actually sends, then stop
#     nginx caching this page so an edit is visible on a normal reload.
#  2. Chrome ignores autocomplete="off" on anything it believes is a login field and fills it with
#     saved addresses. The combination it does respect is autocomplete="new-password" plus a name
#     it has never seen before.
#
set -uo pipefail
CP=/var/www/rumalink/isp
D=$CP/dashboard.html
TS=$(date +%s)
G=$'\e[32m'; Y=$'\e[33m'; N=$'\e[0m'
say(){ echo; echo "${G}===== $* =====${N}"; }

say "1) What the SERVER is sending (not the browser)"
echo -n "   rl-actions-cell occurrences over HTTPS: "
curl -sk "https://rumalinkenterprise.online/isp/dashboard.html" | grep -c "rl-actions-cell"
echo -n "   RL_ROW_MENU_FIRST over HTTPS: "
curl -sk "https://rumalinkenterprise.online/isp/dashboard.html" | grep -c "RL_ROW_MENU_FIRST"
echo "   ${Y}if these are non-zero, the file is fine and the browser is caching${N}"
echo "   cache headers being sent:"
curl -skI "https://rumalinkenterprise.online/isp/dashboard.html" | grep -iE "cache-control|etag|last-modified|expires" | sed 's/^/     /'

say "2) Stop nginx caching the dashboards"
CONF=$(ls /etc/nginx/sites-enabled/* 2>/dev/null | head -1)
echo "   config: $CONF"
sudo cp "$CONF" "${CONF}.bak_$TS"
if sudo grep -q "RL_NO_HTML_CACHE" "$CONF"; then
  echo "   already present"
else
  sudo python3 - "$CONF" <<'PY'
import sys, re
p=sys.argv[1]; s=open(p).read()
block = """
    # RL_NO_HTML_CACHE: these dashboards are edited in place, and a cached copy makes a change look
    # as though it never applied — several minutes were lost chasing a column that was already in
    # the file the server held. The HTML is small; revalidating it every load costs nothing.
    location ~* \\.html$ {
        add_header Cache-Control "no-store, no-cache, must-revalidate" always;
        expires -1;
    }
"""
m = re.search(r'(server\s*\{[^\n]*\n)', s)
if not m:
    print("   ERROR: server block not found"); sys.exit(1)
s = s[:m.end()] + block + s[m.end():]
open(p,'w').write(s); print("   no-cache rule added for .html")
PY
fi
sudo nginx -t 2>&1 | sed 's/^/   /'
sudo systemctl reload nginx && echo "   nginx reloaded"

say "3) Make the search boxes resist Chrome's autofill"
sudo cp "$D" "$CP/.dashboard.html.bak_$TS" && echo "   backed up"
sudo python3 - "$D" <<'PY'
import sys, re, random, string
p=sys.argv[1]; s=open(p).read()
tok = ''.join(random.choice(string.ascii_lowercase) for _ in range(6))
n = 0
def fix(m):
    global n
    t = m.group(0)
    if 'placeholder="Search' not in t and 'search' not in t.lower():
        return t
    n += 1
    t = re.sub(r'\s+autocomplete="[^"]*"', '', t)
    t = re.sub(r'\s+name="[^"]*"', '', t)
    ins = (' autocomplete="new-password" name="rl-' + tok + '-' + str(n) + '"'
           ' data-lpignore="true" data-form-type="other"')
    return (t.rstrip()[:-2] + ins + ' />') if t.rstrip().endswith('/>') else (t[:-1] + ins + '>')
s = re.sub(r'<input\b[^>]*>', fix, s)
open(p,'w').write(s)
print(f"   {n} search input(s) hardened")
print("   /* RL_AUTOFILL_HARD: Chrome ignores autocomplete=off on fields it reads as logins and")
print("      fills them from saved addresses. It does respect new-password plus an unfamiliar name. */")
PY
sudo chown www-data:www-data "$D"
echo "   div balance: $(( $(grep -o '<div' "$D" | wc -l) - $(grep -o '</div>' "$D" | wc -l) ))"
echo "   sample:"; sudo grep -oE '<input[^>]*Search[^>]*>' "$D" | head -2 | cut -c1-160 | sed 's/^/     /'

say "4) Verify once more from outside"
curl -sk "https://rumalinkenterprise.online/isp/dashboard.html" | grep -c "rl-actions-cell" | sed 's/^/   rl-actions-cell: /'
curl -skI "https://rumalinkenterprise.online/isp/dashboard.html" | grep -i cache-control | sed 's/^/   /'

say "5) In the browser"
cat <<'EOS'
   The no-cache header means a normal reload is now enough. For this one time, clear the old
   copy: open the dashboard, press Ctrl-Shift-R, or open it in a private window to be certain.
   The ⋮ should be the first column in All Users, and the search box should start empty.
EOS
