# GSE (Gnome Sequencer Enhanced) for WoW 3.3.5a / Project Ascension

A fork of GnomeSequencer-Enhanced for World of Warcraft 3.3.5a (WotLK, build 12340) with support for Project Ascension, including the Conquest of Azeroth realm.

GSE compiles a sequence of macro lines that advance one step per button press, similar to `/castsequence` but using full macro text per step. It works around the 255-character macro limit by storing each step on a hidden secure button that a normal `/click` macro triggers.

Lineage: GnomeSequencer (semlar), GSE (TimothyLuke), WotLK backport (Gummed), 3.3.5a revival (cerberus), Ascension adaptation (dmjohn0x), and this fork.

## Changes from the previous version

### Ascension compatibility
- Macros previously saved but did nothing. The cause was the custom client's restricted (secure) execution environment rejecting certain words, including `function`, even inside comments in a secure snippet. All secure snippets are now free of comments and disallowed keywords.
- GSE names its hidden button after the sequence. If that name already existed as a global on the client, the old code treated it as an existing button and errored. It now checks whether the global is actually a GSE button, reuses it if so, avoids overwriting another addon's frame, and otherwise claims a free name.

### Classes
- Project Ascension realms use custom classes. The Conquest of Azeroth realm has 21 classes. Other Ascension realms use different class systems. The addon reads the classes the connected realm reports at load and lists them in the editor's class dropdown, and keeps the standard World of Warcraft classes for standard realms.
- A character resolves to its own class instead of falling back to Global. Nothing is tied to a specific realm.
- New sequences default to the Global class.

### Editor
- Fixed the editor name and icon fields locking to numeric-only input.

### Diagnostics
- `/gse diag` runs a self-test (secure environment check, a live compile test, class list, button state) and writes the result to SavedVariables.
- Lua errors are captured to SavedVariables so they can be read from the saved file. `/gse diaglog` prints the log.
- When a sequence fails to compile, GSE reports which sequence and why instead of failing silently.

### Stability and performance
- Added nil checks on client API calls that can return nil on a custom server (class and spec detection, spell and talent lookups, icon resolution).
- Removed global variable pollution and undefined global references.
- The per-step icon updater is throttled instead of running every frame.
- The out-of-combat compile queue is drained safely, so entering combat partway through no longer loses queued saves.
- Fixed a duplicated if/else so the per-sequence Combat reset flag and the Reset out of combat option take effect.
- The Priority step function works on Ascension again. It previously behaved the same as Sequential.
- Fixed the spec-name parser, `/gse showspec`, sequence sharing, version-check errors, and several diagnostic scans.

## Installation

1. Download the latest release.
2. Extract the three folders into `World of Warcraft/Interface/AddOns/`:
   ```
   Interface/AddOns/
     GSE/
     GSE_GUI/
     GSE_LDB/
   ```
3. Enable all three GSE modules on the character-select AddOns screen.
4. `/reload` or log in. 3.3.5a does not load new Lua without this.

## Usage

### Commands

| Command | Effect |
| --- | --- |
| `/gse` | Open the main Sequence Viewer |
| `/gse help` | Print help |
| `/gse showspec` | Show your detected class and spec id |
| `/gse loadsamples` | Load sample macros for your class |
| `/gse debug` | Open the Sequence Debugger |
| `/gse diag` | Run a diagnostic and save the report to SavedVariables |
| `/gse diaglog` | Show the captured Lua error log |
| `/gse checkmacrosforerrors` | Scan the library for corrupt macro versions |
| `/gse cleanorphans` | Delete orphaned GSE macro stubs |
| `/gse cleancorrupted` | Force-remove corrupt sequences that the editor will not open |

### Creating a macro

1. Open `/gse`, then New.
2. Give it a unique name.
3. Add your macro commands, one step per line.
4. Choose a Step Function. Sequential steps through your list in order. Priority repeats earlier steps more often. The editor labels show the pattern for each.
5. Choose the class in the Specialisation / Class ID dropdown. It defaults to Global.
6. Save, create the macro icon, and drag it to your action bar.
7. Press the key to advance the sequence one step per press.

### Project Ascension notes

- Use a unique sequence name. A generic name can match an existing client global. GSE warns instead of erroring, but a unique name avoids it.
- On classless characters, Global works. To organise by class, pick your class from the dropdown. It is listed automatically.
- Custom spells that are not in the default client database are handled through `GetSpellInfo`, so Ascension abilities work.

## Project status

I am no longer working on this. It is left here as a resource for anyone who wants to pick it up. It is not an active project.

## Notes for developers

- Keep strict 3.3.5a compatibility (interface 30300). No retail or later APIs.
- Secure snippets (inside `WrapScript` or `Execute` blocks) must not contain comments or disallowed keywords such as `function`. The custom client rejects them and this silently breaks every macro.
- Nil-check client API calls. On a custom server any native lookup can return nil.
- Do not add globals. Keep additions under the `GSE` table.
- Built on Ace3, LibStub, LibDataBroker, and Lua 5.1 (WoW 3.3.5a embedded).

## Credits

- semlar, original GnomeSequencer
- TimothyLuke, GSE (still maintains the retail version)
- Gummed, WotLK 3.3.5a backport
- cerberus, 3.3.5a revival
- dmjohn0x, initial Ascension adaptation
- This fork, Ascension compatibility and bug-fix pass

## License

Original GSE by TimothyLuke is released under the MIT License. This backport and fork keep the same license. See https://github.com/TimothyLuke/GSE-Advanced-Macro-Compiler for the original project.

This addon is not affiliated with or endorsed by Blizzard Entertainment.
