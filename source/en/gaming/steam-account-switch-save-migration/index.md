<!-- BEGIN ARISE ------------------------------
Title:: "Switching Steam accounts without losing saves"

Author:: "Jose Falanga"
Description:: "Steam Cloud ate my Stardew Valley farms. Here is where save files actually live on Linux, and what to do when you change accounts."
Language:: "en"
Published Date:: "2026-09-28"
Modified Date:: "2026-09-28"
content_header:: "true"
rss_hide:: "false"
---- END ARISE \\ DO NOT MODIFY THIS LINE ---->

# Switching Steam accounts without losing saves

I recently switched Steam accounts on my ChimeraOS machine, and wanted my game progress to come along. Spoiler: I nearly deleted my Stardew Valley farm while trying to move it, and the reason is a piece of documentation that most likely also has you wrong.

This is the corrected version of that procedure, written after getting it wrong first. Every path here was verified on a real machine with roughly 50 games installed, and two of them had to be recovered from backup.

## The myth that causes the damage

Before I did anything, I read the Steam Deck FAQ, which says:

> Can you have multiple Steam accounts on one Steam Deck?
> Yes, and each account on a Steam Deck will keep its own local save data and settings.

This reads like a warning: your saves are per account, switching is dangerous, go migrate them. That framing is what sent me down the wrong path, and it is what I would have told you an hour ago too.

The framing is wrong. What is per-account is a **cloud mirror**, and games mostly do not read the mirror. Real save files are shared by every account on the machine, so the account switch was never the thing putting my farms at risk.

## Where save files actually live

There are three places, and which one applies depends on how the game runs.

**Proton games** keep saves inside the fake Windows drive:

```bash
~/.local/share/Steam/steamapps/compatdata/<appid>/pfx/drive_c/users/steamuser/...
```

Somewhere under `AppData/Roaming`, `AppData/Local`, `AppData/LocalLow`, or `Documents`.

**Native Linux games** use their own directories, and it varies per game:

```bash
~/.config/<Game>/
~/.local/share/<Game>/
```

**Native Windows games** running through Proton sometimes write straight into the install directory, like `steamapps/common/Limbo/savegame.txt`.

And then there is the exception that had me writing a verification script instead of a guide: a minority of games genuinely do save into `userdata/<id>/<appid>/remote/`. Machinarium is one I hit. So neither assumption is safe, and the way out is to ask a tool that already knows.

## The trap: userdata is a mirror

`~/.local/share/Steam/userdata/<accountid>/<appid>/` is what Steam calls the cloud mirror. It is the per-account directory, and it is the one the FAQ is technically describing.

Games do not read it. With cloud sync enabled, Steam pushes mirror state down over the real files, and the newer account's mostly empty mirror wins. What I found on my own machine after launching the games:

```bash
# Stardew Valley, 8 save farms
ls -la ~/.config/StardewValley/Saves/
# drwxr-xr-x 0 user user 4096 Sep 28 20:49 FARMNAME_100000001
# drwxr-xr-x 0 user user 4096 Sep 28 20:49 FARMNAME_100000002
# drwxr-xr-x 0 user user 4096 Sep 28 20:49 FARMNAME_100000003
# ... 69 MB of farms, zero files remaining

# Cuphead, slot 0 had shrunk to the size of a fresh save
# mirror:  35222 bytes
# real:    29575 bytes
```

Here is the part that made it worse, because it is the mistake I would like to save you from. I had copied the old account's mirror into the new account, and the game still saw nothing. My reasoning was that `cp -a` preserves mtimes, so the restored files looked older than cloud state and lost the comparison. So I "fixed" it by touching every file and deleting `remotecache.vdf` to force an upload.

That is precisely what caused the overwrite. Touching mtimes told Steam the mirror was authoritative, and the mirror was the newer account's empty one. I had migrated toward the emptiness instead of away from it.

Turning cloud off is the actual fix, and it has **no command line equivalent**. I am not going to hand-edit `localconfig.vdf` to fake it, because guessing at Steam's private config schema is what got me here.

## What actually needs migrating

One case genuinely does need attention, and it is not the mirror. Some games put the SteamID in the save path, so the new account looks in a directory that does not exist yet:

```bash
find ~ -type d -name "76561197971376839" 2>/dev/null
```

```
~/.local/share/SlayTheSpire2/steam/76561197971376839
~/.local/share/Steam/steamapps/compatdata/2022670/.../SonicSuperstars/Steam/76561197971376839
~/.local/share/Steam/steamapps/compatdata/619780/.../The_Swords_of_Ditto/76561197971376839
```

Slay the Spire 2, Sonic Superstars and The Swords of Ditto all keep their progress under a folder named after the account. Copy old ID to new ID and they are fine:

```bash
cp -a ".../76561197971376839" ".../76561197982487950"
```

To convert an account ID to a SteamID64, add the constant:

```bash
# 11111111 + 76561197960265728 = 76561197971376839
```

## The procedure

```bash
# 1. Work out which accounts are on the box
grep -E "AccountName|AutoLogin" ~/.local/share/Steam/config/loginusers.vdf
ls ~/.local/share/Steam/userdata/

# 2. Quit Steam. Do not reboot mid-procedure, you lose your shell.

# 3. Back up before touching anything. Always.
ludusavi backup
cd ~/.local/share/Steam && tar czf ~/steam-userdata-$(date +%F).tar.gz userdata/

# 4. Learn where the real saves are, then leave them alone
ludusavi backup --preview

# 5. Only fix the SteamID-keyed paths
find ~ -type d -name "<OLD_STEAMID64>" 2>/dev/null

# 6. Cloud off, per game, in the Steam UI:
#    right-click game > Properties > General >
#    uncheck "Keep Game Data in Steam Cloud"

# 7. Verify
ludusavi backup --preview
```

Step 4 is the one people skip, and it is the whole point. I had it backwards for hours.

## Let ludusavi be your map

I spent a while hand-writing path checks, then wrote one badly, and it reported that Stardew had no real data when Stardew's saves were sitting right there in `~/.config/`. Turns out my script only looked inside `compatdata/` and `common/`, so it never saw a single native Linux game. The output looked authoritative and was completely wrong, which is the worst combination available.

[ludusavi](https://github.com/mtkennerly/ludusavi) ships a manifest of real save paths for over 19,000 games, and asks no questions:

```bash
ludusavi backup --preview
```

```
Overall:
  Games: 39 [+39]
  Size: 145.63 MiB
```

It also handles the Proton prefixes and the Windows registry entries I would have missed, and it backs up games **without** Steam Cloud, which on my machine included two games whose only copy lived on that disk.

Installing it on an immutable distro is easy, it ships prebuilt Linux binaries:

```bash
mkdir -p ~/.local/bin
curl -sL https://github.com/mtkennerly/ludusavi/releases/latest/download/ludusavi-v*-linux.tar.gz \
  | tar xz --strip-components=1 -C ~/.local/bin ludusavi
chmod +x ~/.local/bin/ludusavi
```

For JSON, if you are scripting the verification:

```bash
ludusavi backup --preview --api
```

## Verifying for real

A file count tells you files exist. It does not tell you a game will load them, and the failure mode here is nasty: a game reading an empty directory just starts fresh, no error, no prompt.

So after verifying, launch one game of each save type. One native, one Proton, one SteamID-keyed. On my box that meant Stardew Valley, Cuphead, and Slay the Spire 2, and all three came back with their progress intact.

## What you cannot move

Some things are server side and per account, and there is no migration path for any of them:

- Achievements
- Dota 2 MMR and global unlocks
- Workshop subscriptions
- Leaderboard or ranking position

Local files only. And separately, the new account still needs to own or family-share the game before it will launch at all, which is a different problem from having your progress.

## ChimeraOS notes

If you run SteamOS or ChimeraOS, a few things cost me time:

- `chimera-session desktop` sets the session **persistently**. After a reboot you land in GNOME, not gamescope, and Steam will not start. Switch back with `chimera-session steam` before rebooting.
- `systemctl --user stop gamescope-session-plus@steam-plus.service` looks like the right way to stop Steam, but Steam just restarts. The unit can also report `inactive` while Steam is running perfectly well under a different scope arrangement, so it is not a health check. Look for the `steam -srt-logger` process instead.
- Reboot over SSH with `systemctl reboot`; `sudo` wants a password.
- The distro is immutable, so no AUR helper and no `cargo`. That is why ludusavi goes in `~/.local/bin` as a static binary.

## Support

If this saved you some saves, consider supporting the projects that made it possible:

- Support/contribute to [ludusavi](https://github.com/mtkennerly/ludusavi)
- Add [Decky ludusavi](https://decky.net/en/blogs/news-en/saving-games-decky-ludusavi) to your Deck if you want scheduled backups that do not depend on Steam Cloud

And if you have read this far, go and check that cloud toggle on a game you care about. I would rather you not learn this the way I did.
