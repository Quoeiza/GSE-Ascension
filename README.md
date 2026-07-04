# GSE (Gnome Sequencer Enhanced) — WoW 3.3.5a / Project Ascension

An actively-fixed fork of **GnomeSequencer-Enhanced** for World of Warcraft **3.3.5a (WotLK, build 12340)**, with **first-class support for Project Ascension** and its **Conquest of Azeroth** realm (custom classes, custom spell database, classless/custom talent system).

GSE lets you compile a *sequence* of full macro lines that advance one step per button press (like `/castsequence`, but using complete macro text per step and never stalling on an unusable spell). It bypasses the 255-character macro limit by pushing each step into a hidden secure action button that a normal `/click` macro triggers.

> **This fork's headline:** Ascension support — which had broken in the previous version — is restored and working again, on top of a large number of bug fixes, safety improvements, and a few new conveniences. If you were told GSE "doesn't work on Ascension," that's what this fixes.

**Lineage:** semlar (original GnomeSequencer) → TimothyLuke (GSE) → Gummed (WotLK backport) → cerberus (3.3.5a revival) → dmjohn0x (Ascension adaptation) → **this fork (Ascension restoration + bug-fix pass)**.

---

## What's different in this fork

If you're coming from the previous Ascension version, these are the changes that matter.

### Ascension support restored (the big one)
On Project Ascension, macros previously **saved but did nothing**. Two root causes were found and fixed:

- **Custom-client secure environment is stricter.** Conquest of Azeroth's restricted (secure) execution environment rejects certain tokens — notably the word `function` — *even inside a comment* in a secure snippet. A stray comment in the button's OnClick handler was killing every macro on click (`RestrictedExecution.lua: The function keyword is not permitted`). All secure snippets are now comment-free and keyword-clean.
- **Sequence-name / global collisions.** GSE names its hidden button after your sequence. If that name already exists as a global on the client (e.g. `_G["test"]` is a function on Ascension), GSE used to mistake it for an existing button and crash. It now detects collisions: it reuses a real GSE button, refuses to clobber another addon's frame (asking you to rename), or safely claims a free/non-frame name.

### Custom classes are detected automatically
Ascension exposes its full class roster (Conquest of Azeroth has **32 classes** — Sun Cleric, Necromancer, Reaper, Venomancer, Bloodmage, Felsworn, Templar, Runemaster, and more) through the standard client globals. GSE now **discovers whatever classes your client reports at load** and adds them to the editor's class dropdown, while keeping the original 10-12 WotLK classes for standard/other realms. Your character resolves to its own class bucket instead of collapsing into "Global." Nothing is hardcoded to one realm.

### New conveniences
- **ESC → GSE button.** A "GSE" button is added to the in-game menu (Esc), similar to ElvUI, so you don't have to type `/gse`.
- **"Global" is the default class** for new sequences, which is the correct choice for classless characters.

### Built-in diagnostics & automatic error logging
- `/gse diag` runs a full self-test (secure-environment probe, live compile test, class enumeration, button state) and writes the report to SavedVariables.
- **Every Lua error (from any addon) is captured** to `GSEOptions.ErrorLog` automatically, so problems can be diagnosed from the saved file instead of trying to copy chat. `/gse diaglog` shows the log.
- When a sequence fails to compile, GSE now tells you **which one and why**, in chat, instead of failing silently.

### Stability, safety & performance
- Comprehensive nil-checking on WoW API calls that can return `nil` on a custom server (class/spec detection, spell/cooldown/talent lookups, icon resolution) — no more hard crashes when the client doesn't behave like retail.
- Removed global-variable pollution and undefined-global references (reduces taint risk).
- The per-step icon updater is now throttled instead of running (and, with debug on, spamming) every frame.
- The out-of-combat compile queue is drained safely — entering combat mid-drain no longer orphans queued saves.
- Fixed a dead `if/else` so the per-sequence **Combat** reset flag and the **Reset out of combat** option actually work.
- Fixed the `" - "` spec-name parser (it was a broken Lua pattern), `/gse showspec`, sequence transmit (`/gse` send), version-check crashes, and several broken diagnostic scans.

---

## Installation

1. Download the latest release.
2. Extract the three folders into `World of Warcraft/Interface/AddOns/`:
   ```
   Interface/AddOns/
     ├── GSE/
     ├── GSE_GUI/
     └── GSE_LDB/
   ```
3. Enable all three GSE modules on the character-select AddOns screen.
4. `/reload` (or log in). 3.3.5a does not hot-reload Lua.

---

## Usage

### Commands
| Command | Effect |
| --- | --- |
| `/gse` | Open the main Sequence Viewer (also available via the Esc menu button) |
| `/gse help` | Print help |
| `/gse showspec` | Show your detected class/spec id |
| `/gse loadsamples` | Load documented sample macros for your class |
| `/gse debug` | Open the Sequence Debugger |
| `/gse diag` | Run a full diagnostic and save the report to SavedVariables |
| `/gse diaglog` | Show the captured Lua error log |
| `/gse checkmacrosforerrors` | Scan the library for corrupt macro versions |
| `/gse cleanorphans` | Delete orphaned GSE macro stubs |
| `/gse cleancorrupted` | Remove corrupt sequences that can't be edited/deleted |

### Creating a macro
1. `/gse` (or the Esc-menu **GSE** button) → **New**.
2. Give it a **unique** name (see the note on collisions below).
3. Add your macro commands (one step per line).
4. Choose the class in the **Specialisation / Class ID** dropdown (defaults to **Global**).
5. Save, then create the macro icon and drag it to your action bar.
6. Press the key each time you want the sequence to advance to its next step.

### Project Ascension notes
- **Use unique sequence names.** Short generic names (`test`, `PVP`, `WW`, `tank`, `Minimap`…) can collide with client globals. GSE will warn you now instead of crashing, but a unique name avoids the issue entirely.
- **Classless characters:** tagging a macro **Global** always works. If you'd rather organize by your Ascension class, pick it from the dropdown — your custom class is listed automatically.
- **Custom spells** not in the default client DB are recognized (the translator falls back to `GetSpellInfo`), so Ascension abilities work.

---

## Known limitations

- **Combat lockdown:** sequences (re)compile only out of combat — Blizzard's secure rules forbid changing secure attributes in combat. This is by design.
- **No auto-repeat / "press and hold".** You advance a sequence by pressing its key each time. WoW 3.3.5a has no native press-and-hold casting (that is a retail-only feature), and an addon cannot drive continuous casting — the secure system requires a real hardware key/mouse event for every cast, so a timer/`OnUpdate` cannot fire your spells.
- **Taint / TSM:** addons that aggressively hook secure code (notably **TradeSkillMaster**) can taint the secure path and break all sequences. Don't run TSM alongside GSE.
- Maximum of 120 account macros + 18 character macros (Blizzard limit).

---

## For contributors / developers

Maintain **strict 3.3.5a (interface 30300)** compatibility — no retail/MoP+ APIs. A few hard-won rules specific to this environment:

1. **Secure snippets must be comment-free and keyword-clean.** Anything inside a `[=[ … ]=]` block that is `WrapScript`'d or `Execute`'d runs in the restricted secure environment. On custom clients (Conquest of Azeroth) that environment rejects tokens like `function` **even inside comments**, and does not support `print`/function definitions. Do not put comments, `print()`, or function definitions inside those blocks. This single mistake silently breaks every macro.
2. **Never assume `_G[sequenceName]` is a GSE button.** It may be a foreign global. Use the `IsUsableSecureButton` guard.
3. **Nil-check every WoW API call.** On a custom server any native lookup (`UnitClass`, `GetSpellInfo`, `GetSpellCooldown`, `GetNumTalentTabs`, …) can return `nil`. Never let a lookup `error()`, return `""`, or feed `nil` into `tonumber`/string concatenation. Prefer `GSE.isEmpty(x)`.
4. **Realm-agnostic only.** Detect capabilities (does the client expose X?) rather than hardcoding for one realm. Class discovery reads the client's own class tables and falls back safely.
5. **No new globals / no swallowing errors silently.** Keep additions under the `GSE.` table; if you must `pcall`, surface the failure.

Built on the **Ace3** framework, **LibStub**, **LibDataBroker**, and Lua 5.1 (WoW 3.3.5a embedded).

---

## Support

This is a community fork maintained on a best-effort basis. The official Ascension modding Discord ("SzylerAddons") does **not** want GSE discussed there — please respect that and do not ask for GSE support in their channels. Use this repository's issue tracker instead.

## Credits

- **semlar** — original GnomeSequencer
- **TimothyLuke** — GSE (still maintains the retail version)
- **Gummed** — WotLK 3.3.5a backport
- **cerberus** — 3.3.5a revival
- **dmjohn0x** — initial Ascension adaptation
- This fork — Ascension restoration and bug-fix pass

## License

Original GSE by TimothyLuke is released under the MIT License; this backport and fork maintain the same open-source spirit. See https://github.com/TimothyLuke/GSE-Advanced-Macro-Compiler for the original project.

---

*This addon is not affiliated with or endorsed by Blizzard Entertainment.*
