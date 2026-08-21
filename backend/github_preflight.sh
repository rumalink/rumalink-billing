#!/usr/bin/env bash
#
# github_preflight.sh — check what would be published BEFORE pushing to GitHub.
#
# This repo holds Daraja keys, the database password, MikroTik API credentials and SMTP logins.
# Anything committed is in the history permanently: a private repo still exposes it to every
# collaborator, every fork, every future access token, and any accidental flip to public. Rotating
# an M-Pesa key after the fact is far more painful than not pushing it.
#
# READ ONLY. It reports; it pushes nothing.
#
set -uo pipefail
R=/var/www/rumalink
G=$'\e[32m'; Y=$'\e[33m'; RD=$'\e[31m'; N=$'\e[0m'
say(){ echo; echo "${G}===== $* =====${N}"; }

say "1) Repo size and what is tracked"
echo "   working tree: $(sudo du -sh $R 2>/dev/null | cut -f1)"
echo "   tracked files: $(sudo git -C $R ls-files | wc -l)"
echo "   history size: $(sudo du -sh $R/.git 2>/dev/null | cut -f1)"
echo "   largest tracked files:"
sudo git -C "$R" ls-files -z | xargs -0 -I{} sh -c 'test -f "'"$R"'/{}" && echo "$(stat -c%s "'"$R"'/{}") {}"' 2>/dev/null | sort -rn | head -8 | awk '{printf "     %8.1f KB  %s\n", $1/1024, $2}'

say "2) SECRETS — is anything sensitive tracked right now?"
FOUND=0
for f in $(sudo git -C "$R" ls-files | grep -iE "(^|/)\.env|\.env\.|secret|credential|\.pem$|\.key$|id_rsa" || true); do
  echo "   ${RD}TRACKED:${N} $f"; FOUND=1
done
[ "$FOUND" = "0" ] && echo "   ${G}no obvious secret files tracked${N}"

echo "   scanning tracked file CONTENT for credentials:"
sudo git -C "$R" grep -InE "(consumer_secret|CONSUMER_SECRET|passkey|PASSKEY|DB_PASSWORD|SMTP_PASS|api_key|API_KEY|password.*=.*['\"][A-Za-z0-9]{8,})" -- \
  ':!*.md' ':!package-lock.json' 2>/dev/null | grep -viE "process\.env|placeholder|example|your_|xxx|\*\*\*" | head -12 | sed 's/^/     /' || echo "     ${G}nothing obvious${N}"

say "3) SECRETS IN HISTORY — the part that cannot be undone by deleting a file"
echo "   commits that ever touched a .env or key file:"
sudo git -C "$R" log --all --oneline --name-only 2>/dev/null | grep -iE "^\.env|/\.env|\.pem$|\.key$" | sort -u | head -10 | sed 's/^/     /' || echo "     ${G}none${N}"
echo "   does .env exist in any commit?"
if sudo git -C "$R" rev-list --all --objects 2>/dev/null | grep -qE "(^| )\.env$|/\.env$"; then
  echo "     ${RD}YES — it is in the history and would be published${N}"
else
  echo "     ${G}no${N}"
fi

say "4) .gitignore"
if sudo test -f "$R/.gitignore"; then sudo cat "$R/.gitignore" | sed 's/^/     /'; else echo "   ${RD}there is no .gitignore${N}"; fi

say "5) Clutter that should not be published"
echo "   node_modules tracked: $(sudo git -C $R ls-files | grep -c '^backend/node_modules/' || echo 0)"
echo "   .bak files tracked:   $(sudo git -C $R ls-files | grep -cE '\.bak|\.bak_[0-9]+' || echo 0)"
echo "   recovery dirs tracked: $(sudo git -C $R ls-files | grep -cE '\.rec2_|\.v[0-9]_|\.backup_|\.trace_' || echo 0)"
echo "   log files tracked:    $(sudo git -C $R ls-files | grep -cE '\.log$' || echo 0)"

say "6) Remotes and what is already pushed"
sudo git -C "$R" remote -v | sed 's/^/   /'
echo "   commits ahead of the local origin: $(sudo git -C $R rev-list --count origin/master..master 2>/dev/null || echo '?')"
echo "   has anything ever been pushed to github?"
sudo git -C "$R" ls-remote --exit-code github >/dev/null 2>&1 && echo "     remote reachable" || echo "     ${Y}remote unreachable or needs credentials${N}"

say "7) Verdict"
cat <<'EOS'
   If section 2 or 3 flagged anything, do NOT push yet — the fix is different depending on which:
     tracked now but never committed  -> add to .gitignore, git rm --cached, then push
     present in the history           -> the history must be rewritten, or start a fresh repo with
                                          no history, because deleting the file in a new commit
                                          leaves the old one readable forever

   Section 5 is about size and noise rather than safety, but node_modules and the .rec2_/.v4_
   recovery copies would bloat the repo and publish dead code that no longer runs.
EOS
