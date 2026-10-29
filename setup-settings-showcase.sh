#!/usr/bin/env bash
# setup-settings-showcase.sh — one-command repo-settings pass for the
# PUBLIC showcase repo (andrewdhorowitz/andrewdhorowitz.github.io).
#
# Run it from a clone of the repo, signed in as the repo owner (Termux
# or a GitHub Codespace, with the GitHub CLI `gh` installed +
# authenticated):
#   bash setup-settings-showcase.sh
# It is safe to re-run: every step is idempotent and best-effort — each
# prints its own ✓ / ✗ / – line and the script carries on regardless.
#
# What it does (all via `gh api`):
#   * Wiki OFF, Projects OFF. Discussions is only READ, never changed:
#     the site's Giscus comments run on Discussions, so the script
#     reports ✓ if it is on and warns loudly if it is off.
#   * Dependabot alerts ON; Dependabot security updates ON.
#   * Secret scanning ON; secret scanning push protection ON (separate
#     calls, separate result lines). The repo is public, so both are
#     free and expected to succeed.
#   * CodeQL default setup ON, language javascript-typescript (the
#     showcase is a static HTML/JS site — no Python).
#   * The minimal "main-basics" ruleset (blocks deletions + force
#     pushes only; Repository admins always bypass; NO required PRs or
#     status checks — the owner's no-lockout rule), created only if no
#     ruleset already covers the default branch.
#   If `gh` is missing or unauthenticated, the settings section is
#   skipped with one line; the cleanup below still happens.
#
# Results: printed to the terminal AND written to a local
# setup-results.txt in this clone. This repo is PUBLIC, so the results
# file is deliberately left UNTRACKED — never committed. The cleanup
# commit at the end stages ONLY this script's own deletion.
set -uo pipefail
cd "$(dirname "$0")"

SCRIPT_NAME="setup-settings-showcase.sh"
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
attempt() { # attempt <label> <command...>
  local label="$1"
  shift
  if "$@" >/dev/null 2>&1; then
    report ok "$label"
  else
    report fail "$label (failed — continuing)"
  fi
}
is_plan_gated() { # is_plan_gated <captured api output>
  printf '%s' "$1" | grep -qiE 'upgrade to github pro|advanced security|make this repository public'
}
attempt_sa() { # attempt_sa <label> <json body>
  # PATCHes one security_and_analysis feature at a time so secret
  # scanning and push protection report SEPARATE results. A plan-gate
  # refusal is reported as a skip, not a failure (not expected on this
  # public repo, but the wording stays honest if it ever happens).
  local label="$1" body="$2" out
  if out="$(gh api -X PATCH "repos/$OWNER/$REPO" --input - <<<"$body" 2>&1)"; then
    report ok "$label"
  elif is_plan_gated "$out"; then
    report skip "$label — plan-gated on this repo (needs GitHub Pro here); skipped"
  else
    report fail "$label (failed — continuing)"
  fi
}
attempt_gated() { # attempt_gated <label> <command...>
  local label="$1"
  shift
  local out
  if out="$("$@" 2>&1)"; then
    report ok "$label"
  elif is_plan_gated "$out"; then
    report skip "$label — plan-gated on this repo (needs GitHub Pro here); skipped"
  else
    report fail "$label (failed — continuing)"
  fi
}

main() {
echo "== Repo settings (via gh api) =="

# Work out owner/repo from the git remote instead of hard-coding them.
REMOTE_URL="$(git remote get-url origin 2>/dev/null || true)"
OWNER_REPO="$(printf '%s' "$REMOTE_URL" | sed -E 's#^(git@github\.com:|https://github\.com/)##; s#\.git$##')"
OWNER="${OWNER_REPO%%/*}"
REPO="${OWNER_REPO##*/}"

if ! command -v gh >/dev/null 2>&1 || ! gh auth status >/dev/null 2>&1; then
  echo "Skipped: the GitHub CLI (gh) is missing or not signed in here."
  echo "Settings can be done in the web UI instead."
  RESULTS+="– Repo settings skipped (gh unavailable)"$'\n'
elif [ "$OWNER" = "$OWNER_REPO" ] || [ -z "$OWNER" ] || [ -z "$REPO" ]; then
  echo "Skipped: could not read owner/repo from the git remote ($REMOTE_URL)."
  RESULTS+="– Repo settings skipped (remote not parsed)"$'\n'
else
  echo "Repo: $OWNER/$REPO"

  attempt "Wiki feature off" gh api -X PATCH "repos/$OWNER/$REPO" --input - <<'JSON'
{"has_wiki": false}
JSON

  attempt "Projects feature off" gh api -X PATCH "repos/$OWNER/$REPO" --input - <<'JSON'
{"has_projects": false}
JSON

  # Discussions: READ-ONLY check. Giscus comments depend on it — this
  # script never changes it, it only reports.
  DISCUSSIONS="$(gh api "repos/$OWNER/$REPO" --jq '.has_discussions' 2>/dev/null || echo unknown)"
  if [ "$DISCUSSIONS" = "true" ]; then
    report ok "Discussions on (checked only — Giscus needs it; left untouched)"
  elif [ "$DISCUSSIONS" = "false" ]; then
    report fail "WARNING: Discussions is OFF — Giscus comments will break. Turn it back on in Settings → General → Features. This script did NOT change it."
  else
    report skip "Discussions state unreadable — check it by hand (Giscus needs it ON; this script never changes it)"
  fi

  attempt "Dependabot alerts on" gh api -X PUT "repos/$OWNER/$REPO/vulnerability-alerts"

  attempt "Dependabot security updates on" gh api -X PUT "repos/$OWNER/$REPO/automated-security-fixes"

  attempt_sa "Secret scanning on" \
    '{"security_and_analysis": {"secret_scanning": {"status": "enabled"}}}'

  attempt_sa "Secret scanning push protection on" \
    '{"security_and_analysis": {"secret_scanning_push_protection": {"status": "enabled"}}}'

  # CodeQL default setup — public repo, so free. The showcase is a
  # static site: javascript-typescript only.
  attempt_gated "CodeQL default setup on" gh api -X PATCH "repos/$OWNER/$REPO/code-scanning/default-setup" --input - <<'JSON'
{"state": "configured", "languages": ["javascript-typescript"]}
JSON

  # Main ruleset — only create it if no ruleset already covers the
  # default branch. The GET response is checked for a plan-gate message
  # BEFORE anything tries to parse it as a list.
  if RULESETS_OUT="$(gh api "repos/$OWNER/$REPO/rulesets" 2>&1)"; then
    EXISTING="$(gh api "repos/$OWNER/$REPO/rulesets" --jq '[.[] | select(((.conditions.ref_name.include) // []) | index("~DEFAULT_BRANCH"))] | length' 2>/dev/null || echo error)"
    case "$EXISTING" in
      ''|*[!0-9]*)
        report fail "Main ruleset check unreadable — skipped creating (continuing)"
        ;;
      0)
        attempt "Main ruleset 'main-basics' created (blocks deletions + force pushes; repo admins always bypass)" gh api -X POST "repos/$OWNER/$REPO/rulesets" --input - <<'JSON'
{
  "name": "main-basics",
  "target": "branch",
  "enforcement": "active",
  "bypass_actors": [
    {"actor_id": 5, "actor_type": "RepositoryRole", "bypass_mode": "always"}
  ],
  "conditions": {"ref_name": {"include": ["~DEFAULT_BRANCH"], "exclude": []}},
  "rules": [{"type": "deletion"}, {"type": "non_fast_forward"}]
}
JSON
        ;;
      *)
        report ok "Main ruleset already exists — skipped creating another"
        ;;
    esac
  elif is_plan_gated "$RULESETS_OUT"; then
    report skip "Main ruleset 'main-basics' — plan-gated on this repo (needs GitHub Pro here); skipped"
  else
    report fail "Main ruleset check failed — skipped creating (continuing)"
  fi
fi

echo ""
echo "== Summary =="
printf '%s' "$RESULTS"
}

# Capture the whole run to a temp log OUTSIDE the repo first; when it
# has finished, copy it to a LOCAL setup-results.txt. This repo is
# public: the results file stays untracked and is never committed.
main 2>&1 | tee "$TMPLOG"
cp "$TMPLOG" "$RESULTS_FILE"
rm -f "$TMPLOG"
echo ""
echo "Full output saved locally in $RESULTS_FILE (untracked — delete it whenever; it is NOT committed)."

echo ""
echo "== Cleanup =="
# Delete this script and commit ONLY that deletion (pathspec commit —
# the untracked setup-results.txt and anything else in the tree are
# never staged). If the commit or push fails, the settings above still
# applied — delete the file by hand later.
push_cleanup() { # plain push, retrying with an upstream if the branch has none
  git push -q 2>/dev/null || git push -q -u origin "$(git branch --show-current 2>/dev/null || echo main)"
}
git rm -q "$SCRIPT_NAME" >/dev/null 2>&1 || rm -f "$SCRIPT_NAME"
if git commit -q -m "Remove setup-settings-showcase.sh (settings applied)" -- "$SCRIPT_NAME" && push_cleanup; then
  echo "Cleanup committed and pushed — only the script's removal was committed."
else
  echo "NOTE: couldn't commit/push the cleanup. Everything above still applied;"
  echo "delete $SCRIPT_NAME by hand whenever convenient."
fi
