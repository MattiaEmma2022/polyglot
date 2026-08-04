#!/usr/bin/env bash
# ---------------------------------------------------------------
# install-into-repo.sh — copy Seam into a repo you have already
# cloned, then commit and push.
#
# Run it from inside the unzipped "polyglot" folder:
#
#   ./install-into-repo.sh ~/polyglot
#
# where the argument is the path to YOUR CLONE (the folder that
# came from `git clone git@github.com:MattiaEmma2022/polyglot.git`).
#
# Everything is copied except .git, so your clone keeps its own
# remote and history. Safe to re-run — it becomes an update.
# ---------------------------------------------------------------
set -uo pipefail

BOLD=$'\033[1m'; DIM=$'\033[2m'; RED=$'\033[31m'; GRN=$'\033[32m'; YEL=$'\033[33m'; OFF=$'\033[0m'
ok()    { printf '%s✓%s %s\n' "$GRN" "$OFF" "$*"; }
warn()  { printf '%s!%s %s\n' "$YEL" "$OFF" "$*"; }
die()   { printf '%s✗%s %s\n' "$RED" "$OFF" "$*" >&2; exit 1; }
head_() { printf '\n%s%s%s\n' "$BOLD" "$*" "$OFF"; }

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET="${1:-}"

[ -n "$TARGET" ] || die "Give me the path to your clone:  ./install-into-repo.sh ~/polyglot"

# ---------------------------------------------------------------
# 1. Verify both ends before touching anything
# ---------------------------------------------------------------
head_ "Checking source and destination"

[ -f "$SRC/index.html" ] || die "index.html is not next to this script. Run it from inside the unzipped polyglot folder."
ok "source: $SRC"

TARGET="${TARGET/#\~/$HOME}"
[ -d "$TARGET" ] || die "No such directory: $TARGET"
TARGET="$(cd "$TARGET" && pwd)"

[ "$SRC" != "$TARGET" ] || die "Source and destination are the same folder. Nothing to do."

[ -d "$TARGET/.git" ] || die "$TARGET is not a git clone (no .git inside). Clone the repo first:
  git clone git@github.com:MattiaEmma2022/polyglot.git"
ok "destination: $TARGET"

REMOTE="$(git -C "$TARGET" remote get-url origin 2>/dev/null || true)"
[ -n "$REMOTE" ] || die "That clone has no 'origin' remote. Add one:
  git -C '$TARGET' remote add origin git@github.com:MattiaEmma2022/polyglot.git"
ok "origin: $REMOTE"

# Anything uncommitted in the clone would get mixed into our commit.
if [ -n "$(git -C "$TARGET" status --porcelain 2>/dev/null)" ]; then
  warn "The clone has uncommitted changes. They will be committed together with Seam."
  git -C "$TARGET" status --short | sed 's/^/    /'
  printf '\nContinue? [y/N] '
  read -r reply
  case "$reply" in [yY]*) ;; *) die "Stopped. Nothing was copied." ;; esac
fi

# ---------------------------------------------------------------
# 2. Line the local branch up with the remote BEFORE copying.
# Doing this first means the working tree is still clean, so git
# can move branches around without tripping over new files.
# ---------------------------------------------------------------
head_ "Lining up with the remote"

git -C "$TARGET" fetch -q origin 2>/dev/null || warn "Could not reach origin. Carrying on offline; the push at the end may fail."

# What does the remote call its default branch?
DEFAULT="$(git -C "$TARGET" symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null | sed 's#^origin/##')"
if [ -z "$DEFAULT" ]; then
  for b in main master; do
    if git -C "$TARGET" show-ref -q --verify "refs/remotes/origin/$b"; then DEFAULT="$b"; break; fi
  done
fi

if [ -z "$DEFAULT" ]; then
  # Truly empty repo — no branches on the remote at all. We choose.
  DEFAULT=main
  git -C "$TARGET" checkout -q -B main
  ok "remote is empty; using a fresh 'main'"
else
  ok "remote default branch: $DEFAULT"
  CURRENT="$(git -C "$TARGET" symbolic-ref --quiet --short HEAD 2>/dev/null || echo '')"
  if [ "$CURRENT" != "$DEFAULT" ]; then
    git -C "$TARGET" checkout -q -B "$DEFAULT" "origin/$DEFAULT" \
      || die "Could not check out $DEFAULT. Sort the clone out by hand, then re-run."
    ok "switched from '${CURRENT:-detached}' to $DEFAULT"
  fi
  git -C "$TARGET" merge -q --ff-only "origin/$DEFAULT" 2>/dev/null \
    && ok "up to date with origin/$DEFAULT" \
    || warn "Local and remote have diverged; will rebase before pushing."
fi
BRANCH="$DEFAULT"

# ---------------------------------------------------------------
# 3. Copy — everything except .git
# ---------------------------------------------------------------
head_ "Copying files"

# tar preserves the tree and the exclude is exact, unlike cp with globs
# which silently misses dotfiles such as .gitignore and .github/
tar -cf - --exclude=./.git --exclude=./node_modules -C "$SRC" . \
  | tar -xf - -C "$TARGET" || die "Copy failed."

chmod +x "$TARGET"/*.sh 2>/dev/null || true

# The deploy workflow triggers on a branch name; match whatever the remote uses.
if [ "$BRANCH" != "main" ] && [ -f "$TARGET/.github/workflows/pages.yml" ]; then
  sed -i "s/branches: \[main\]/branches: [$BRANCH]/" "$TARGET/.github/workflows/pages.yml"
  ok "deploy workflow retargeted at '$BRANCH'"
fi

for f in index.html manifest.json sw.js README.md .gitignore .github/workflows/pages.yml icons/icon-192.png; do
  [ -e "$TARGET/$f" ] && ok "$f" || warn "missing: $f"
done

# ---------------------------------------------------------------
# 4. Commit, then push — rebasing once if the remote moved
# ---------------------------------------------------------------
head_ "Committing"

cd "$TARGET" || die "Could not enter $TARGET"

git add -A
if git diff --cached --quiet; then
  warn "Nothing changed — the files were already identical. Skipping the commit."
else
  git commit -q -m "Add Seam: code-switching trainer for multilinguals" || die "Commit failed."
  ok "committed: $(git log -1 --pretty='%h %s')"
fi

head_ "Pushing to $BRANCH"

PUSHED=0
if git push -u origin "$BRANCH" 2>&1; then
  PUSHED=1
else
  warn "Push rejected. Trying a rebase onto origin/$BRANCH, then pushing again."
  if git pull --rebase -q origin "$BRANCH" && git push -u origin "$BRANCH"; then
    PUSHED=1
    ok "rebased and pushed"
  fi
fi

if [ "$PUSHED" -ne 1 ]; then
  printf '\n'
  warn "Still rejected. Almost always SSH, so test it:"
  cat <<'FIX'

      ssh -T git@github.com

  Expect: "Hi <you>! You've successfully authenticated". If instead you get
  "Permission denied (publickey)", make a key and register the public half:

      ssh-keygen -t ed25519 -C "your@email"
      cat ~/.ssh/id_ed25519.pub        # paste into github.com/settings/keys
      ssh -T git@github.com            # test again

  Your files are copied and committed locally either way — nothing is lost.
  Once ssh works, just run:  git push -u origin main

FIX
  exit 1
fi

# ---------------------------------------------------------------
# 5. What to do next
# ---------------------------------------------------------------
if printf '%s' "$REMOTE" | grep -q 'github\.com'; then
  SLUG="$(printf '%s' "$REMOTE" | sed -E 's#^.*github\.com[:/]##; s#\.git$##')"
  OWNER="${SLUG%%/*}"; NAME="${SLUG##*/}"
  # Pages hostnames are lowercase even when the account name is not
  HOST="$(printf '%s' "$OWNER" | tr '[:upper:]' '[:lower:]')"

  head_ "Done"
  ok "https://github.com/$SLUG"
  printf '\n%sTurn on the live version:%s\n' "$BOLD" "$OFF"
  printf '  1. https://github.com/%s/settings/pages\n' "$SLUG"
  printf '  2. Source: %sGitHub Actions%s  (not "Deploy from a branch")\n' "$BOLD" "$OFF"
  printf '  3. Wait for the run at https://github.com/%s/actions to go green\n' "$SLUG"
  printf '\n  It will be served at %shttps://%s.github.io/%s/%s\n' "$BOLD" "$HOST" "$NAME" "$OFF"
  printf '\n%sOpen that on your phone in Chrome, then menu -> Add to home screen.%s\n' "$DIM" "$OFF"
  printf '%sIt installs standalone and works offline after the first load.%s\n\n' "$DIM" "$OFF"
else
  head_ "Done"
  ok "Pushed to $REMOTE on branch $BRANCH"
  printf '\n%sThat remote is not on github.com, so there is no Pages step to run.%s\n\n' "$DIM" "$OFF"
fi
