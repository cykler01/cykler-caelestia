# Updating

We try to keep this fork merged with upstream `caelestia-dots/shell` regularly, so you should get
upstream fixes and features here too (best effort, no promises).

## The script

Run it from inside your clone - by default it just pulls any new commits on this fork and
rebuilds/reinstalls:

```sh
./update.sh
```

Flags:

- `--upstream` - also merge in `caelestia-dots/shell` (adding the `upstream` remote if needed, and
  showing you what changed before merging)
- `--yes` / `-y` - skip the confirmation prompts

It refuses to run if you have uncommitted local changes, so commit or stash first.

## From inside the session

*Settings → Updates* does the same thing without a terminal: it checks the repo, lists the incoming
commits, and can pull, rebuild, install (through `pkexec`) and restart the shell. See
[updates.md](updates.md).

## By hand

```sh
cd cykler-caelestia
git pull
cmake --build build
sudo cmake --install build
```

To pull in upstream yourself:

```sh
git remote add upstream https://github.com/caelestia-dots/shell.git
git fetch upstream
git merge upstream/main
```

## After an upstream merge

Two things in the fork are easy to break with an upstream change, so they are worth a quick check after
merging:

- **Shell asset paths.** The shipped defaults use the `root:` prefix (`root:/assets/kurukuru.gif`),
  which has to be resolved against the shell's asset directory. If the logo, gifs or placeholder
  images come back blank, that resolution is what broke.
- **The special workspaces switch.** It is enforced by the shell rather than by the Hyprland config
  (see [special-workspaces.md](special-workspaces.md)), so it depends on the `openwindow`, `movewindow`
  and `activespecial` events still arriving as expected.

A clean build is worth it if anything looks odd after a large upstream merge:

```sh
rm -rf build
cmake -B build -G Ninja -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/
cmake --build build
sudo cmake --install build
```
