# Updates

*Nexus → Updates* checks the git checkout this shell was built from and can pull, rebuild, install and
restart the shell without leaving the session.

[▶ Demo](https://cykler.dev/caelestia/demos/updates.mp4)

## The page

- **Check** fetches the tracked branch and reports what you are on, whether the checkout is dirty, and
  how many commits behind you are, with the incoming commit subjects listed.
- **Install** pulls, rebuilds, installs through `pkexec` (so it asks for your password) and then
  restarts the shell, printing each step as it goes.
- If the checkout has uncommitted changes, the page stops and asks what to do rather than guessing:
  install anyway (stashing and restoring them) or leave them.
- A failed pull aborts the merge cleanly and nothing is installed, so a conflict cannot leave you with
  a half-updated shell. Build and install failures are reported the same way, with the last lines of
  the build output.

## Where it looks

```json
"services": {
    "repoPath": "",
    "updateBranch": "main"
}
```

`repoPath` defaults to `~/Documents/Github/cykler-caelestia` when empty, and `updateBranch` defaults to
`main`.

If your checkout lives somewhere else, the page shows the path it is using and a **Browse** button
next to it, which opens a folder picker rather than making you type the path out. The dialog starts in
the directory currently configured, and the chosen folder is written straight to `repoPath`.

## How it works

The page drives `scripts/shell-update.sh` in that checkout, which is what actually talks to git and
cmake:

```sh
scripts/shell-update.sh check   "$repo" main
scripts/shell-update.sh install "$repo" main [stash]
```

The script prints machine-readable lines (`HEAD:`, `BRANCH:`, `DIRTY:`, `BEHIND:`, `LOG:`, `STEP:`,
`WARN:`, `ERROR:`, `DONE`) that the page turns into its status row. It never restarts the shell itself
- the shell does that, detached, after `DONE` - and it restores stashed changes even when the update
fails partway.

## The update notification

The toast that tells you a new commit has landed points at *Settings → Updates* and opens the page when
clicked. It is off by default:

```json
"utilities": {
    "toasts": {
        "repoUpdateAvailable": true
    }
}
```

## See also

- [updating.md](updating.md) for the command-line route (`./update.sh`, or merging upstream by hand).
