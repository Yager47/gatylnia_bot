---
name: ship
description: Commit the reviewed changes, open a PR and merge it once CI is green; CI then deploys to Heroku and checks the deploy. Only when the user types /ship.
argument-hint: "[commit subject]"
disable-model-invocation: true
---

# Ship

The user typing `/ship` approves the current uncommitted changes they've
reviewed: commit, push, PR, merge once CI is green. The merge deploys: CI's
`deploy` job pushes `main` to Heroku and runs `bin/post-deploy-check`. Don't
ask for another confirmation. Do stop at the first
failure and report it; never work around a red check, and never force-push
`main`.

Arguments (`$ARGUMENTS`): an optional commit subject.

## Environment

- The shell is zsh: write paths out explicitly (`$VARS` don't word-split).
- Start Ruby commands with `source ~/.rvm/scripts/rvm 2>/dev/null; rvm use "$(cat .ruby-version)" >/dev/null 2>&1;`
  (the version pinned in `.ruby-version`, also used by the Gemfile, CI and Heroku).
  If `rvm use` fails with "bad file descriptor", export `GEM_HOME`, `GEM_PATH`
  and `PATH` for `~/.rvm/rubies/ruby-<version>` and its gemsets instead.
- Production: Heroku app `gatylnia`, deployed by CI's `deploy` job on every
  push to `main` that passes CI (needs the `HEROKU_API_KEY` repo secret).
  Don't `git push heroku main` yourself unless the user asks.
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

5. **PR, CI, merge.** Don't watch or poll CI (no `gh pr checks --watch`,
   loops or timed re-checks): GitHub waits instead. The `main requires CI`
   ruleset requires `test`, `lint` and `scan_ruby`, and the repo allows
   auto-merge.
   - `gh pr create --base main` with a short Summary and Test plan (what was
     run locally), ending with the "Generated with Claude Code" line.
   - Check CI once (`gh pr view <number> --json statusCheckRollup`):
     - all three green: `gh pr merge <number> --merge`;
     - any failed: stop, report which and why (`gh run view --log-failed`),
       and leave the PR open;
     - still running: enable auto-merge with the `mcp__ccd_pr__set_auto_merge`
       tool (merge method `merge`). GitHub merges when the checks pass; a
       failed check leaves the PR open.
   - Once merged: `git switch main` and `git pull --ff-only origin main`.

6. **Deploy status.** Nothing to run: the merge starts the CI run on `main`,
   whose `deploy` job pushes to Heroku and runs `bin/post-deploy-check`
   (release phase, Solid Queue Worker, `/up`, no R1x/H10/crash). Don't wait
   for it. If you merged in step 5, look once at
   `gh run list --branch main --workflow CI -L 1 --json status,conclusion,url`
   and report it as is (usually still running). Whenever the user later asks
   about the deploy, check that run once:
   - success: read the release number from the job log
     (`gh run view <id> --log --job <deploy job id>`, "Release vN succeeded")
     and skim `heroku logs -n 300 -a gatylnia` for app-level `Error` lines
     the script doesn't judge;
   - failed: report the failing step and its log lines (`gh run view <id>
     --log-failed`) and suggest `heroku rollback -a gatylnia`; don't roll
     back on your own.

## Report

A few lines: commit hash and subject, PR link, CI result (or "auto-merge
pending"), and the deploy run's state with its link (or that it starts once
auto-merge merges). Mention anything the user should try in the
chat, or any warning seen. No command transcripts: the tool rows already show them.
