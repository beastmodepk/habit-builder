# Review it, sign it as yours, push to your GitHub

The zip of this project includes the full `.git` history, so you can review
every commit before anything leaves your laptop.

## 1. Review

```bash
unzip atomic-habits-ios.zip && cd atomic-habits-ios
git log --oneline            # the commit story, newest first
git log --format=full        # authors + the Assisted-by: trailer on each commit
git show <hash>              # read any single commit in full
```

## 2. Make the commits yours and sign off

`-s` adds a `Signed-off-by: Your Name <you@email>` trailer. Note two things:

- `git commit --amend -s` only amends the **latest** commit.
- To sign off (and re-author) **every** commit, replay them in a rebase:

```bash
git config user.name "Your Name"
git config user.email "you@email"

# Rebase all commits, amending each one with your sign-off and your authorship:
GIT_SEQUENCE_EDITOR=true git rebase -i --root \
  -x "git commit --amend --no-edit --reset-author -s"
```

This rewrites the hashes (expected — nothing has been pushed yet), sets you as
author/committer, appends your `Signed-off-by:` next to the existing
`Assisted-by: Muse Wonder` trailer, which stays.

### If you want a cryptographic "Verified" badge on GitHub

`-s` (sign-off) is a text trailer, not a signature. For GitHub's Verified
badge you need `-S` with a GPG or SSH signing key configured
(`git config commit.gpgsign true`, `git config user.signingkey ...`), then add
`--gpg-sign` to the rebase. Optional — sign-off alone is a perfectly good
public record.

## 3. Push to your GitHub

Create a **new empty** repository on GitHub (no README, no .gitignore — this
repo already has both), then:

```bash
git remote add origin git@github.com:<you>/atomic-habits-ios.git
git push -u origin main
git push origin v0.1.0        # push the MVP tag too
```

Done — history, trailers, and tag land exactly as you reviewed them.
