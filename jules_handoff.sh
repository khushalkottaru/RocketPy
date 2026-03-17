#!/bin/bash
# ─────────────────────────────────────────────────────────
# jules_handoff.sh
# Checks out a Jules scout branch and launches Claude Code with context
#
# Usage:
#   ./jules_handoff.sh                  # interactive branch picker
#   ./jules_handoff.sh <branch-name>    # direct branch name
# ─────────────────────────────────────────────────────────

# ── Config — only thing to change when reusing across repos
DEFAULT_BRANCH="master"
UPSTREAM_FALLBACK="https://github.com/RocketPy-Team/RocketPy.git"
# ─────────────────────────────────────────────────────────

set -e

REPO_DIR=$(git rev-parse --show-toplevel 2>/dev/null)
if [ -z "$REPO_DIR" ]; then
  echo "❌ Not inside a git repo."
  exit 1
fi

cd "$REPO_DIR"

# ── Detect upstream repo slug ─────────────────────────────

UPSTREAM_URL=$(git remote get-url upstream 2>/dev/null || echo "")
if [ -z "$UPSTREAM_URL" ]; then
  echo "❌ No upstream remote found. Run: git remote add upstream $UPSTREAM_FALLBACK"
  exit 1
fi

UPSTREAM_REPO=$(echo "$UPSTREAM_URL" \
  | sed 's|https://github.com/||' \
  | sed 's|git@github.com:||' \
  | sed 's|[.]git$||')

echo "📡 Upstream: $UPSTREAM_REPO"

# ── Step 1: Determine the branch ─────────────────────────

if [ -n "$1" ]; then
  BRANCH="$1"
else
  echo ""
  echo "🔍 Fetching recent branches from origin..."
  git fetch origin --quiet

  echo ""
  echo "Recent branches (newest first):"
  echo "──────────────────────────────"

  BRANCHES=$(git branch -r --sort=-committerdate \
    | grep 'origin/' \
    | grep -v "origin/$DEFAULT_BRANCH" \
    | sed 's|origin/||' \
    | head -20)

  if [ -z "$BRANCHES" ]; then
    echo "No branches found other than $DEFAULT_BRANCH."
    echo "Jules may not have created a branch yet."
    exit 1
  fi

  i=1
  while IFS= read -r branch; do
    echo "  $i) $branch"
    i=$((i+1))
  done <<< "$BRANCHES"

  echo ""
  printf "Enter number of the Jules branch to work on: "
  read -r SELECTION

  BRANCH=$(echo "$BRANCHES" | sed -n "${SELECTION}p" | xargs)

  if [ -z "$BRANCH" ]; then
    echo "❌ Invalid selection"
    exit 1
  fi
fi

# ── Step 2: Check out the branch ─────────────────────────

echo ""
echo "📥 Checking out branch: $BRANCH"

git fetch origin "$BRANCH" --quiet

if git show-ref --verify --quiet "refs/heads/$BRANCH"; then
  git checkout "$BRANCH"
  git pull origin "$BRANCH" --quiet
else
  git checkout -b "$BRANCH" "origin/$BRANCH"
fi

echo "✅ On branch: $BRANCH"

# ── Step 3: Read scout_report.md ─────────────────────────

echo ""
echo "📋 Reading scout report..."

SCOUT_REPORT=""
SELECTED=""

if [ -f "scout_report.md" ]; then
  SELECTED=$(grep "SELECTED ISSUE:" scout_report.md | grep -oE '[0-9]+' | head -1)

  if [ -z "$SELECTED" ]; then
    echo ""
    echo "👉 Open scout_report.md and fill in the SELECTED ISSUE number, then re-run."
    exit 0
  fi

  echo "✅ Selected issue: #$SELECTED"

  SCOUT_REPORT=$(python3 << PYEOF
import sys, re

selected = "$SELECTED"
with open("scout_report.md") as f:
    text = f.read()

pattern = r"(## Issue " + selected + r" \u2014.*?)(?=## Issue \d|\Z)"
match = re.search(pattern, text, re.DOTALL)
if match:
    print(match.group(1).strip())
else:
    print(text)
PYEOF
)
  echo "✅ Extracted issue $SELECTED from scout_report.md"
else
  echo "⚠️  No scout_report.md found on this branch"
fi

# ── Step 4: Check for competing PRs ──────────────────────

ISSUE_NUMBER="$SELECTED"
ISSUE_STATUS=""
ISSUE_TITLE=""
ISSUE_BODY=""

if command -v gh &> /dev/null && [ -n "$ISSUE_NUMBER" ]; then
  echo "🔍 Checking upstream issue #$ISSUE_NUMBER..."
  ISSUE_JSON=$(gh issue view "$ISSUE_NUMBER" --repo "$UPSTREAM_REPO" --json state,title,body 2>/dev/null || echo "")

  if [ -n "$ISSUE_JSON" ]; then
    ISSUE_STATUS=$(echo "$ISSUE_JSON" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('state','unknown'))")
    ISSUE_TITLE=$(echo "$ISSUE_JSON"  | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('title',''))")
    ISSUE_BODY=$(echo "$ISSUE_JSON"   | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('body','')[:800])")
    echo "📌 Issue #$ISSUE_NUMBER: $ISSUE_STATUS — $ISSUE_TITLE"

    if [ "$ISSUE_STATUS" = "closed" ]; then
      echo ""
      echo "⛔  Issue #$ISSUE_NUMBER is already closed. Pick a different issue."
      exit 0
    fi
  fi

  echo "🔍 Checking for competing PRs..."
  COMPETING=$(gh pr list \
    --repo "$UPSTREAM_REPO" \
    --search "fixes #$ISSUE_NUMBER" \
    --json number,title,isDraft,url \
    2>/dev/null || echo "[]")

  PR_COUNT=$(echo "$COMPETING" | python3 -c "import sys,json; print(len(json.load(sys.stdin)))")

  if [ "$PR_COUNT" -gt "0" ]; then
    echo ""
    echo "⛔  STOP — There is already an open PR for issue #$ISSUE_NUMBER:"
    echo "$COMPETING" | python3 -c "
import sys, json
for pr in json.load(sys.stdin):
    draft = ' [DRAFT]' if pr.get('isDraft') else ''
    print('  #' + str(pr['number']) + draft + ': ' + pr['title'])
    print('  ' + pr['url'])
"
    echo ""
    echo "   Pick a different issue."
    exit 0
  else
    echo "✅ No competing PRs — you're clear to proceed."
  fi
fi

# ── Step 5: Build context file and launch Claude Code ────

CONTEXT_FILE="/tmp/jules-context-$(date +%s).md"

cat > "$CONTEXT_FILE" << CONTEXT
# Jules Handoff — $UPSTREAM_REPO

## Branch
$BRANCH

## Selected Issue
#${ISSUE_NUMBER:-"unknown"} — ${ISSUE_TITLE:-"unknown"}
Status: ${ISSUE_STATUS:-"unknown"}

---

## Scout Report
${SCOUT_REPORT:-"(no scout_report.md found)"}

---

## Issue Body
${ISSUE_BODY:-"(could not fetch)"}

---

## Instructions for Claude Code

Read CLAUDE.md before doing anything else — it contains scope rules and
conventions you must follow.

1. Read the scout report and issue above carefully.
2. Run existing tests for the relevant module first to establish a baseline:
   \`python -m pytest tests/ -x -q -k <relevant_test_file>\`
3. Implement the fix. Stay strictly within the scope of the issue.
4. Write tests using pytest.approx for any float assertions.
5. Ensure all new public functions have NumPy docstrings.
6. When done, give me a 3-sentence summary of what changed for the PR description.
CONTEXT

echo ""
echo "🚀 Launching Claude Code..."
echo ""

claude < "$CONTEXT_FILE"