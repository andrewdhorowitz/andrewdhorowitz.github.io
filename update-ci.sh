#!/usr/bin/env bash
# update-ci.sh — one-command workflow refresh for the showcase repo (andrewdhorowitz/andrewdhorowitz.github.io).
#
# Run it from the repo root, signed in as the repo owner (Termux or a
# GitHub Codespace):
#   bash update-ci.sh
#
# What it does:
#   1. REPLACES .github/workflows/links.yml and
#      .github/workflows/lighthouse.yml with the staged copies in
#      ci-src/ when they differ, and reports "already" for any that
#      are identical. Unlike the install passes — which never
#      overwrote an installed workflow — this refresh deliberately
#      replaces exactly these two files. The staged copies are the
#      kit v3.7 THIN CALLERS: each keeps its workflow name ("Links"
#      / "Lighthouse"), its triggers, and its permissions exactly
#      as installed today, but the jobs move out — links.yml now
#      calls the shared reusable
#      andrewdhorowitz/fleet-ci/.github/workflows/fleet-links.yml@main
#      and lighthouse.yml calls
#      andrewdhorowitz/fleet-ci/.github/workflows/fleet-lighthouse.yml@main
#      passing this repo's one per-repo input, its audit URL
#      (https://andrewdhorowitz.com/). The baseline ci.yml was centralized the same way in
#      kit v3.6/v3.6.1 and is NOT touched by this refresh. Future
#      kit fixes to the link check or the audit land centrally in
#      the fleet-ci repo and need no per-repo update runs.
#      (The workflows travel at ci-src/ because the Muse GitHub
#      App cannot push files under .github/workflows/; the repo
#      owner can.)
#   2. Writes the full run output to setup-results.txt in the repo
#      root (captured to a temp file first and copied in only when
#      the run has finished, so the file always holds the complete
#      output — `cat setup-results.txt` afterwards shows the whole
#      run for review). This repo is PUBLIC, so the file stays local
#      and untracked: it is never staged or committed.
#   3. Deletes itself and ci-src/, and lands the removal plus the
#      refreshed workflows in ONE cleanup commit, which it pushes.
# It is safe to re-run: after a successful run there is nothing
# left staged, and a repeat run reports both workflows already
# current.
set -uo pipefail
cd "$(dirname "$0")"

RESULTS_FILE="setup-results.txt"
TMPLOG="$(mktemp)"

RESULTS=""
report() { # report <ok|fail|skip> <label>
  local mark="✓"
  [ "$1" = "fail" ] && mark="✗"
  [ "$1" = "skip" ] && mark="–"
  echo "$mark $2"
  RESULTS+="$mark $2"$'\n'
}

install_one() { # install_one <staged> <target> <label>
  local staged="$1" target="$2" label="$3"
  if [ ! -f "$staged" ]; then
    report skip "No staged $label found ($staged) — nothing to do"
  elif [ -f "$target" ] && cmp -s "$staged" "$target"; then
    report skip "Workflow $label already current ($target) — left as-is"
  elif [ -f "$target" ]; then
    cp "$staged" "$target"
    report ok "Workflow $label refreshed ($target) — kit v3.7 thin caller (jobs centralized in the public fleet-ci repo)"
  else
    cp "$staged" "$target"
    report ok "Workflow $label installed ($target) — kit v3.7 thin caller (jobs centralized in the public fleet-ci repo)"
  fi
}

main() {
  echo "== File install =="
  mkdir -p .github/workflows
  install_one ci-src/links.yml .github/workflows/links.yml links.yml
  install_one ci-src/lighthouse.yml .github/workflows/lighthouse.yml lighthouse.yml

  echo ""
  echo "== Summary =="
  printf '%s' "$RESULTS"
}

# Capture the whole run to a temp log OUTSIDE the repo first; only when
# it has fully finished is the log copied to setup-results.txt, so the
# file always holds the complete, final output of the run.
main 2>&1 | tee "$TMPLOG"
cp "$TMPLOG" "$RESULTS_FILE"
rm -f "$TMPLOG"
echo ""
echo "Full output saved locally in $RESULTS_FILE (untracked — delete it whenever; it is NOT committed)."

echo ""
echo "== Cleanup =="
# One commit: this script removed, ci-src/ removed, the refreshed
# workflows added. The staging below is pathspec-explicit.
# setup-results.txt is deliberately NOT staged — it stays a local,
# untracked file (public repo). If the commit or push fails, the
# refresh above still stands — tidy the files by hand.
git rm -q update-ci.sh >/dev/null 2>&1 || rm -f update-ci.sh
if [ -d ci-src ]; then
  git rm -rq ci-src >/dev/null 2>&1 || rm -rf ci-src
fi
[ -d .github/workflows ] && git add -- .github/workflows 2>/dev/null || true
git add -A -- update-ci.sh ci-src 2>/dev/null || true
push_cleanup() { # plain push, retrying with an upstream if the branch has none
  git push -q 2>/dev/null || git push -q -u origin "$(git branch --show-current 2>/dev/null || echo main)"
}
if git diff --cached --quiet; then
  echo "Nothing staged — cleanup already done."
elif git commit -q -m "Refresh links.yml + lighthouse.yml (kit v3.7 thin callers — jobs centralized in the public fleet-ci repo, via update-ci.sh)" && push_cleanup; then
  echo "Cleanup committed and pushed."
else
  echo "NOTE: couldn't commit/push the cleanup. Everything above still applied;"
  echo "commit the removal of update-ci.sh + ci-src/ by hand whenever convenient."
fi
