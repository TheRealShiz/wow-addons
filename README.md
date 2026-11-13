# wow-addons

A small, headless World of Warcraft addon updater for Linux, built on the
[CurseForge API](https://docs.curseforge.com/). It keeps a short list of
addons current for one game flavor (written for WoW: Forever, works for any
flavor CurseForge tags) and runs from a systemd user timer, with no GUI.

## Why

The official CurseForge app is officially supported only on Ubuntu, and the
open-source Linux managers I tried either dropped CurseForge or don't ship
it in their Linux builds. Some addons (TradeSkillMaster, for one) update
almost daily, so updating by hand isn't practical.

## What it does

- Reads a list of addon slugs or project IDs from a config file
- Asks CurseForge for the newest file tagged for your flavor and release channel
- Downloads it from the official download URL and swaps it into your AddOns folder
- Removes folders an addon no longer ships; never touches addons it didn't install
- Records what it installed in `~/.local/state/wow-addons/state.json`

### CurseForge API terms

- Uses only the `downloadUrl` the API returns. If an author has disabled
  third-party distribution, that addon is skipped with a message.
- Does not cache API data. Lookups are repeated on every run. The state file
  only records what was installed locally.
- Personal use: about 20 addons, a few runs a day.

### TradeSkillMaster

If you run a TSM desktop app, such as
[tsm-app-linux](https://github.com/exceptionptr/tsm-app-linux), let it manage
TSM and its AppHelper, and leave `tradeskill-master` out of this tool's config.

## Requirements

- Python 3.11+ (standard library only)
- A CurseForge API key ([console.curseforge.com](https://console.curseforge.com/))

## Install

```bash
mkdir -p ~/.local/bin ~/.config/wow-addons ~/.config/systemd/user
install -m 755 wow-addons.py ~/.local/bin/
cp config.example.toml ~/.config/wow-addons/config.toml   # then edit it
cp systemd/wow-addons.service systemd/wow-addons.timer ~/.config/systemd/user/
(umask 077; echo 'YOUR_API_KEY' > ~/.config/wow-addons/api_key)
```

The key can also come from the `CURSEFORGE_API_KEY` environment variable.
Keep it out of git.

## Usage

```bash
wow-addons.py versions   # list CurseForge's WoW version types (check your flavor exists)
wow-addons.py status     # installed vs. latest, changes nothing
wow-addons.py check      # same, exits 10 if anything is outdated
wow-addons.py update     # install missing and update outdated addons (default)
```

Run updates automatically 2 minutes after login and every 6 hours:

```bash
systemctl --user daemon-reload
systemctl --user enable --now wow-addons.timer
journalctl --user -u wow-addons     # see what it did
```

## CrateMath (in-game addon)

`addons/CrateMath` is a small WoW: Forever addon that prices Waylaid Crate
bundles in gold per Merchant's Favor, using TSM prices (Auctionator as a
fallback).

- Hover a Waylaid Crate, in your bags or on the Auction House, to see the
  cheapest bundle that fills it and what each MF costs you.
- `/cm` ranks every known bundle by gold per MF.
- `/cm targets` shows what the MF recipes we're saving toward cost in gold.
- `/cm check` confirms the item IDs in `Data.lua` match the game.
- Crate and Craftsman's Writ tooltips are recorded in the `CrateMath`
  SavedVariables file, so bundle lists and writ requests can be filled in
  from real data. `/cm log` shows the counts.

Bundle data comes from beta-era community guides and is incomplete (Artisan
rewards, Herbs/Curiosities/Parts bundles). Edit `Data.lua` as you learn more.

Install by linking it into your AddOns folder, so `git pull` updates it:

```bash
ln -s "$PWD/addons/CrateMath" \
  ~/.local/share/Steam/steamapps/compatdata/<APPID>/pfx/drive_c/Program\ Files\ \(x86\)/World\ of\ Warcraft/_forever_/Interface/AddOns/CrateMath
```

## License

MIT
