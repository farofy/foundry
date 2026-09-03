#!/bin/sh
# Self-test for scripts/git-hooks/commit-msg. Run: sh tests/commit-msg.test.sh
# CI runs this on every pull request.

HOOK="$(dirname "$0")/../scripts/git-hooks/commit-msg"
TMP=$(mktemp)
PASS=0
FAIL=0

check() { # $1 = pass|block  $2 = label  $3 = message
  printf '%s\n' "$3" > "$TMP"
  if sh "$HOOK" "$TMP" >/dev/null 2>&1; then got=pass; else got=block; fi
  if [ "$got" = "$1" ]; then
    PASS=$((PASS + 1))
    printf '  ok    %-42s [%s]\n' "$2" "$got"
  else
    FAIL=$((FAIL + 1))
    printf '  FAIL  %-42s [got %s, want %s]\n' "$2" "$got" "$1"
  fi
}

# Build subjects of exactly 72 and 73 characters, all lowercase.
P='feat(skills): '
LEN72="$P$(printf 'a%.0s' $(seq 1 $((72 - ${#P}))))"
LEN73="$P$(printf 'a%.0s' $(seq 1 $((73 - ${#P}))))"

echo "Valid:"
check pass  "scope present, lowercase" "feat(setup): add cross-platform bootstrap"
check pass  "breaking change"          "feat(api)!: drop legacy endpoint"
check pass  "scope with a hyphen"      "refactor(commit-convention): clarify rules"
check pass  "over 50, warns not blocks" "feat(setup): add the cross-platform desktop control bootstrap"
check pass  "exactly 72 characters"     "$LEN72"
check pass  "style, a standard type"   "style(hook): wrap lines at 78 columns"
check pass  "acronym inside the subject" "fix(api): handle HTTP 500"
check pass  "ticket id inside the subject" "fix(ci): revert FDR-42"

# Non-ASCII subjects: the limit counts characters, so these must classify the
# same way as their ASCII counterparts even though they use more bytes.
VI72="feat(auth): thêm aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
VI73="feat(auth): thêm aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
check pass  "72 characters, non-ASCII"  "$VI72"

echo "Skipped (not ordinary commits):"
check pass  "merge"                     "Merge branch 'feature/x' into main"
check pass  "merge pull request"        "Merge pull request #12 from farofy/x"
check pass  "merge commit by sha"       "Merge commit '99d2008abc'"
check pass  "octopus merge by sha"      "Merge commit 'a1'; commit 'b2' into oct"
check pass  "merge branches, octopus"   "Merge branches 'a' and 'b'"
check pass  "merge remote-tracking"     "Merge remote-tracking branch 'origin/main'"
check pass  "merge tag"                 "Merge tag 'v1.0'"
check pass  "revert"                    "Revert \"feat(a): b\""
check pass  "fixup"                     "fixup! feat(a): b"
check pass  "squash"                    "squash! feat(a): b"
check pass  "amend"                     "amend! feat(a): b"
check pass  "reapply, revert of revert" "Reapply \"feat(a): b\""

echo "Must be rejected:"
check block "no type"                  "update stuff"
check block "invalid type"             "feature: add x"
check block "type outside the standard" "infra(ci): add runner"
check block "missing scope"            "feat: add something"
check block "no space after the colon" "feat(setup):missing space"
check block "all caps subject"         "feat(setup): ADD SOMETHING"
check block "capitalised first word"   "feat(setup): Add something"
check block "capital after a hyphen"   "feat(setup): Re-add something"
check block "73 characters"            "$LEN73"
check block "73 characters, non-ASCII" "$VI73"
check block "uppercase scope"          "feat(Setup): add something"
check block "empty description"        "feat(setup): "
check block "whitespace-only description" "feat(setup):  "
check block "subject ends with a period" "feat(setup): add a thing."
check block "period hidden by a trailing space" "feat(setup): add a thing. "
check block "merge-like prose, not a merge" "Merged the thing badly."
check block "prose starting merge branch" "Merge branch policy update"
check block "prose starting reapply"   "Reapplying the old approach"
check block "comment-led subject"      "#42 hotfix"
check block "two trailing periods"     "feat(setup): wait for it.."

# These cases need a file, because a leading blank line cannot survive the
# variable the check helper uses.
checkfile() { # $1 = pass|block  $2 = label  $3 = message written verbatim
  printf '%b' "$3" > "$TMP"
  if sh "$HOOK" "$TMP" >/dev/null 2>&1; then got=pass; else got=block; fi
  if [ "$got" = "$1" ]; then
    PASS=$((PASS + 1)); printf '  ok    %-42s [%s]\n' "$2" "$got"
  else
    FAIL=$((FAIL + 1)); printf '  FAIL  %-42s [got %s, want %s]\n' "$2" "$got" "$1"
  fi
}

echo "Read from a file (leading blank line, body separation):"
checkfile pass  "leading blank line, valid subject" "\nfeat(setup): add x\n"
checkfile block "leading blank line, bad subject"   "\nBAD SUBJECT.\n"
checkfile pass  "body after a blank line"           "feat(a): add x\n\nbody\n"
checkfile block "body with no blank line"           "feat(a): add x\nbody\n"

echo "Footer (co-author trailer capitalisation):"
CA_OK="$(printf 'feat(setup): add x\n\nCo-authored-by: Ann <ann@example.com>')"
CA_TITLE="$(printf 'feat(setup): add x\n\nCo-Authored-By: Ann <ann@example.com>')"
CA_LOWER="$(printf 'feat(setup): add x\n\nco-authored-by: Ann <ann@example.com>')"
CA_UPPER="$(printf 'feat(setup): add x\n\nCO-AUTHORED-BY: Ann <ann@example.com>')"
CA_HALF1="$(printf 'feat(setup): add x\n\nCo-Authored-by: Ann <ann@example.com>')"
CA_HALF2="$(printf 'feat(setup): add x\n\nCo-authored-By: Ann <ann@example.com>')"
check pass  "co-author trailer, correct"       "$CA_OK"
check pass  "co-author trailer, title case"    "$CA_TITLE"
check block "co-author trailer, lowercase"     "$CA_LOWER"
check block "co-author trailer, all caps"      "$CA_UPPER"
check block "co-author trailer, half title case" "$CA_HALF1"
check block "co-author trailer, half lower case" "$CA_HALF2"

rm -f "$TMP"
echo
echo "Result: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ] || exit 1
