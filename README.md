# Pajama Sam 3 — Linux installer

Automated installer for *Pajama Sam 3: You Are What You Eat From Your Head to Your Feet* (Humongous Entertainment, 2000) on Linux Mint, Ubuntu, and Debian via ScummVM. Reads the original CD, copies the game data into a local directory, registers the game with ScummVM, and creates a launcher and menu entry. No Wine needed — ScummVM runs HE-engine games natively.

## What's in here

A single script, `install-pajama-sam-3.sh`. Run it once with the disc inserted and it handles the whole pipeline from dependency install through launching the game.

## Requirements

A Linux Mint, Ubuntu, or Debian system with `sudo` access. The first run will install `scummvm` from the package repos if it's not already present. You also need the original *Pajama Sam 3* CD inserted — on a default Mint desktop this auto-mounts at something like `/media/$USER/Pajama Sam 3`. The disc is needed only during the install; once the script finishes, you can eject it and never need it again.

## Usage

Insert the disc, then from the directory containing the script:

```bash
chmod +x install-pajama-sam-3.sh
./install-pajama-sam-3.sh -y
```

The `-y` flag skips all confirmation prompts. The game launches as soon as the install finishes. Future launches: run `pajama-sam-3` from a terminal, or click "Pajama Sam 3" in your application menu.

If the auto-detect can't find the disc, pass it explicitly:

```bash
./install-pajama-sam-3.sh -y -s "/media/$USER/Pajama Sam 3"
```

## Launching the game (and a known quirk)

Some versions of ScummVM (2.5.1 and a few others) have a bug where launching directly via `scummvm pajama3` from the command line throws **"Error running game: Game data not found"** — even though the game files are right where they should be. The launcher script handles this gracefully: it tries the direct launch first, and if that fails, it falls through to opening the ScummVM GUI launcher.

If you see the "Game data not found" dialog when starting the game, just **click OK**. ScummVM will return to its main launcher window with the game already highlighted in the list (you'll see "Pajama Sam 3: You Are What You Eat..." in green). **Double-click that entry** — or click it once and press Start — and the game will boot normally. Once you've done this once, you can keep using `pajama-sam-3` from the terminal or the menu entry the same way every time. Updating to a newer ScummVM (2.6 or later) makes the bug go away entirely.

## Under the hood

The script scans `/media/$USER/`, `/run/media/$USER/`, `/media/`, and `/mnt/` for a directory containing `PAJAMA3.HE0`, `PAJAMA3.HE2`, and `PAJAMA3.HE4`. Filename matching is case-insensitive, so it works whether the mount exposes uppercase (typical for ISO9660) or lowercase names. Once it locates the disc, it installs `scummvm` if missing, then copies four files into `~/.local/share/games/pajama-sam-3/`: the three `PAJAMA3.HE*` resource files plus the `PAJAMA3.(A)` audio file. Total around 245 MB. The Windows executable, the help file, the autorun graphics, the catalog of other Humongous games, and the bundled demo are all skipped — ScummVM has no use for any of them.

After the copy, the game is registered with ScummVM by running `scummvm -p $INSTALL_DIR --add --game=pajama3`, which adds the game to ScummVM's config at `~/.config/scummvm/scummvm.ini` under the target name `pajama3` — non-interactively, no GUI. If `--add` fails for any reason, the script falls back to writing the config section directly. Finally, a launcher script lands at `~/.local/bin/pajama-sam-3` that tries to start the game directly and falls back to the GUI launcher if ScummVM throws the "Game data not found" error described above. A `.desktop` entry in `~/.local/share/applications/` makes the game appear in your application menu under Games.

There's no fake-CD setup needed. ScummVM reimplements the SCUMM HE engine from scratch — it reads the data files directly and never does a CD-presence check.

## File locations

Everything lives under your home directory. The game data is at `~/.local/share/games/pajama-sam-3/`. ScummVM's config is at `~/.config/scummvm/scummvm.ini`, with a `[pajama3]` section corresponding to this install. The launcher script is `~/.local/bin/pajama-sam-3` and the desktop menu entry is `~/.local/share/applications/pajama-sam-3.desktop`. Set `PJS3_DIR` in the environment before running the script to override the install location.

## Bonus features from ScummVM

Running through ScummVM instead of the original Windows binary gets you a few things the 2000 release didn't have. F5 opens the in-game menu where you can save and load to any of dozens of slots. Alt+Enter toggles fullscreen on the fly. Various pixel scalers and filters (HQ2x, AdvMAME, SuperEagle, and others) are available per-game in the ScummVM GUI, along with aspect-ratio correction and optional CRT-style shaders.

## Troubleshooting

If the game doesn't appear in the ScummVM GUI launcher even though `pajama-sam-3` works from the terminal, open the GUI by running `scummvm` with no arguments — the entry should be there. If not, check that `~/.config/scummvm/scummvm.ini` has a `[pajama3]` section pointing at the install dir.

To start over from scratch, wipe the install dir and re-run the script with the disc inserted:

```bash
rm -rf ~/.local/share/games/pajama-sam-3
./install-pajama-sam-3.sh -y
```

## Uninstall

Remove the game data, the launcher, and the menu entry, and delete the `[pajama3]` section from ScummVM's config (easiest done from the ScummVM GUI: select the game, click "Remove Game"). To do it all from the terminal:

```bash
rm -rf ~/.local/share/games/pajama-sam-3
rm -f ~/.local/bin/pajama-sam-3
rm -f ~/.local/share/applications/pajama-sam-3.desktop
update-desktop-database ~/.local/share/applications 2>/dev/null
```

Then open `~/.config/scummvm/scummvm.ini` in a text editor and delete the `[pajama3]` section.

## Notes

The script assumes you own the original CD. ScummVM is open source and freely distributed via the standard package repositories on Mint, Ubuntu, and Debian; it does not include any game data — you bring your own from the disc you bought.
