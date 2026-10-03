# 🍌 BananaRepublik Partnerguild

**Share professions and recipes with your guild and a partner guild: find the crafter, whisper them, done.**

![Version](https://img.shields.io/badge/version-2.2.1-ffd100) ![Client](https://img.shields.io/badge/client-1.12.1-blue) ![License](https://img.shields.io/badge/license-MIT-lightgrey)

Every guild member scans their professions, the addon shares the recipes over the guild channel, and everyone can search who can craft what. With a 12-character invite code, a second guild joins in: vanilla 1.12 cannot send addon messages across guilds, so the partner guild's data travels over a hidden, password-protected chat channel. Built for the guild **Banana Republic**. Lua 5.0, no libraries.

## Features

- **Recipe database for the whole guild:** open a profession window and the addon scans it. Search by recipe, filter by profession and subcategory, see reagents, icon and crafter.
- **Partner guild via invite code:** one guild creates a code, the other enters it. The code holds channel and password; the addon hides its protocol messages from the chat and throttles sending.
- **Partner markers:** crafters from the partner guild carry a blue `<Guild>` tag. Partners show as *online* or *not reachable* (the addon cannot tell logged out from no addon) and appear in the whisper menu automatically.
- **Guildless partners work too:** they are listed as `<no guild (Name)>` and shared via the partner channel only.
- **Connect members without typing:** *Connect guild members* sends the code to everyone in your guild who has the addon. New members ask for it themselves 8 seconds after login.
- **Sync that only fetches what is outdated:** `/brpp sync` compares hashes, `/brpp send` sends everything. CSV export for Discord and Excel.
- German and English, minimap button.

## Screenshots

| Recipes | Crafters | Partner setup | Sharing |
|---|---|---|---|
| ![Recipes](screenshots/01-recipes.png) | ![Crafters](screenshots/02-crafters.png) | ![Partner setup](screenshots/03-partner-setup.png) | ![Sharing](screenshots/04-sharing.png) |

## Installation

1. Download the [latest release](https://github.com/BananaForge/BananaRepublik_Partnerguild/releases) and put the `BananaRepublik_Partnerguild` folder into `Interface/AddOns/`.
2. Enable it on the character screen and open the window with `/brpp show`.

When updating, delete the old folder first. **Every member needs the addon.** It is a standalone addon with its own saved variables (`BRPPDB`) and prefix, so it can run next to BananaRepublicProfs, but the two do not share data.

## Usage

**Partner setup (once):** guild A runs `/brpp partner create` and passes the code on (whisper, Discord). Guild B runs `/brpp partner add <code>`. Then click *Connect guild members* so everyone in your guild is connected, and send your data with `/brpp send`.

| Command | Effect |
|---|---|
| `/brpp show` | Open or close the window |
| `/brpp scan` / `rescan` | Scan the open profession / allow rescanning |
| `/brpp send` / `sync` | Send all professions / fetch only what is outdated |
| `/brpp versioncheck` | Which addon version do guildmates run? |
| `/brpp delete [prof\|all]` | Delete one or all professions |
| `/brpp scanbank` | Scan the bank manually |
| `/brpp export` | CSV export for Discord/Excel |
| `/brpp lang en\|de\|auto` | Language |
| `/brpp debug` / `about` | Debug output / info and support |
| `/brpp partner` | Partner status |
| `/brpp partner create` / `add <code>` | Create a code / join with a code |
| `/brpp partner code` / `newcode` | Show the code / generate a new one (the old one stops working) |
| `/brpp partner push` | Send the code to your own guild |
| `/brpp partner list` | List known partner guilds |
| `/brpp partner remove <guild>` | Drop that guild's data |
| `/brpp partner leave` | End the partnership and remove all foreign data |

## Technical notes

- Client 1.12.1 (Interface 11200), saved variables `BRPPDB`, addon prefix `BRPP0`.
- Database keys are `Charname@Guild`, the same string goes over the wire. Bank data is never shared with partner guilds.
- Limits: the partner channel is joined 5 seconds after login. A partner sync takes noticeably longer than a guild sync on purpose (server spam protection). Private servers may behave differently from original vanilla; if chunks arrive broken, `/brpp debug` shows why.
- Details on the design, the code and the limits: [docs/ENTWICKLUNG.md](docs/ENTWICKLUNG.md).

## To do

- [ ] About 20 missing Enchanting recipes (Runed Rods, Wands, Oils) in `BananaRepublik_Partnerguild_RecipeMaps.lua`. A pure data gap.

## Contributing

Pull requests welcome, tested in-game on a 1.12 client. Lua 5.0 rules: no `#`, `%`, `string.match`, `select` or `...`; script handlers read `this`, `event` and `arg1..9` as globals; German texts in `Locale.lua` use umlauts and `ss` instead of `ß`.

## Changelog

See [CHANGELOG.md](CHANGELOG.md).

## Credits and license

Part of **BananaForge** (with [BananaRepublicProfs](https://github.com/BananaForge/BananaRepublicProfs), [BananaBank](https://github.com/BananaForge/BananaBank) and [BananaLootline](https://github.com/BananaForge/BananaLootline)). Development: **Lumihunt**, guild Banana Republic. Free forever; if you want to support it, send in-game mail to Lumihunt. MIT, see [LICENSE](LICENSE).
