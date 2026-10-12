---
name: ship
description: Commit the reviewed changes, open and merge a PR once CI is green, and deploy to Heroku in one go. Only when the user types /ship.
argument-hint: "[commit subject] [--no-deploy]"
disable-model-invocation: true
---

# Ship

The user typing `/ship` approves the current uncommitted changes they've
reviewed: commit, push, PR, wait for CI, merge, deploy. Don't ask for another
confirmation. Do stop at the first failure and report it; never work around a
red check, and never force-push `main`.

Arguments (`$ARGUMENTS`): an optional commit subject; `--no-deploy` skips step 6.

## Environment

- The shell is zsh: write paths out explicitly (`$VARS` don't word-split).
- Start Ruby commands with `source ~/.rvm/scripts/rvm 2>/dev/null; rvm use 3.3.6 >/dev/null 2>&1;`
- Production: Heroku app `gatylnia`, deployed with `git push heroku main`.
  Health check: `https://gatylnia-6e3de023de50.herokuapp.com/up`.
- Local `main` has no upstream: use `git pull --ff-only origin main`.

## Steps

1. **Check what's being shipped.** `git status --short` and `git diff --stat`.
   Stop if there's nothing to ship. List the files you'll commit; leave out
   unrelated untracked files (scratch files, `.claude/settings.local.json`).
   If unsure whether a file belongs, ask instead of guessing.

2. **Branch.** If on `main`, create a short descriptive branch
   (`fix/…`, `perf/…`, `refactor/…`, `chore/…`). Otherwise stay on the current
   feature branch.

3. **Verify locally**, and stop on any failure:
   - `bundle exec rspec` (all green)
   - `bin/rubocop` (no offenses, whole repo)
   - If `db/migrate` changed: `bin/rails db:migrate` is reflected in
     `db/schema.rb`, and the migration was flagged per CLAUDE.md.

4. **Commit and push.** Stage the listed files by explicit path, then commit
   in the same command (`git add … && git commit …`) so a failed add stops it.
   Message: the `$ARGUMENTS` subject, or a short one in the repo's style
   (imperative, under ~60 chars), plus at most two lines of body and the
   Co-Authored-By trailer. Keep it brief. `git push -u origin <branch>`.

5. **PR, CI, merge.**
   - `gh pr create --base main` with a short Summary and Test plan (what was
     run locally), ending with the "Generated with Claude Code" line.
   - `gh pr checks <branch> --watch --interval 15`. All of `test`, `lint` and
     `scan_ruby` must pass. If any fails, stop: report which and why (read the
     job log with `gh run view --log-failed`), and leave the PR open.
   - `gh pr merge <number> --merge`, then `git switch main` and
     `git pull --ff-only origin main`.

6. **Deploy** (skip with `--no-deploy`):
   - `git push heroku main`; note the release number.
   - If the change has migrations, check `heroku releases:output <vN> -a gatylnia`.
   - Verify: `/up` returns 200, and `heroku logs -n 300 -a gatylnia` shows
     Solid Queue's Supervisor and Worker started with no `Error`, `crashed`
     or `R14` since the release.
   - If the deploy or a check fails, report it with the relevant log lines
     and suggest `heroku rollback -a gatylnia`; don't roll back on your own.

## Report

A few lines: commit hash and subject, PR link, CI result, release number,
health check. Mention anything the user should try in the chat, or any
warning seen. No command transcripts: the tool rows already show them.
