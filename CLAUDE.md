# Birdsong: Developer Notes

> Started from `wow-addon-template`. Read `WOW_ADDON_PLAYBOOK.md` before changing anything. Tjommie's `CLAUDE.md` (GitHub Radewest/tjommie) is the worked example.

## What it is
- A roleplay-flavoured birder's field guide for WoW Forever. It plays the game's own bird calls and zone soundscapes (by FileDataID, so no audio is shipped) and keeps a life list of every bird you target or mouse over.
- **Owner:** Harry. **Licence:** MIT. **CurseForge project ID:** (not yet). **GitHub:** (not yet).
- **Name:** Birdsong (confirmed by Harry, 2026-11-09).
- **Art:** icon generated with Higgsfield (GPT Image 2.6), 2026-11-09. `media/icon.tga` (64 px) and `media/pin.tga` (64 px round crop for map pins); 400 px CurseForge logo and 1024 px original are in the OneDrive `wow-forever-addons` folder.
- **Current version:** v0.3.2 (local test build, not published)

## Architecture
| File | Role |
|---|---|
| Core.lua | Namespace, saved variables, event bus, `ns:Print`/`ns:Chat`, slash commands (`/birds`, `/birdsong`), addon-compartment click, welcome line |
| Bugs.lua | Self bug log (`/birds bugs`) |
| Sounds.lua | **Generated** by `tools/gen_sounds.py` from the community listfile: `ns.SOUNDS[bird][callType] = {fileIDs}`, `ns.AMBIENCE_IDS[biome] = {day, night}` |
| Atlas.lua | **Generated** by `tools/gen_atlas.py`: `ns.KINDS[npcID] = {n, s, l1, l2, d, z}`: 58 classic bird creatures with species, levels, display (model) ID and spawn zones |
| Spawns.lua | **Generated** by `tools/gen_spawns.py`: `ns.SPAWNS[npcID][zone] = {x1,y1,...}` (pfQuest spawn points, thinned) for map pins |
| Zones.lua | Zone notes: `ns.MUSIC` (classic zone music themes, FileDataIDs), `ns.ZONE_NOTES[zone] = {soundscape, music, note=}` (best guesses, sourced notes only), `ns.MUSIC_CREDIT` |
| Birds.lua | The field guide: species, recognition words, notes, call types, soundscapes; Atlas indexes (`ZONE_KINDS`, `SPECIES_KINDS`, `ATLAS_ZONES`), `LivesIn`, `SpeciesZones`, `MatchBird` |
| Audio.lua | `PlayFile`/`PlayBird`/`PlayAmbience`/`StopSound`; one sound at a time; remembers files the client doesn't have |
| Sightings.lua | Life list: target/mouseover out of combat → creature ID from GUID matched to the Atlas (name words as fallback) → `db.sightings` (species), `db.kinds` (creatures), `db.zones`; journal `db.log` (one entry per bird/zone/day, game hour saved); fires `NEW_SPECIES` / `NEW_KIND` / `RARE_SEEN`; binoculars emote `ns:Spot`; `/birds test` |
| Buddy.lua | Birding buddy: `db.buddy`, Battle.net/whisper transport (like Tjommie), wire `Q`/`L`/`N`, life list as a hex bitmask over sorted Atlas IDs, "Use my tjommie" reads `TjommieDB.buddy` |
| Badges.lua | 24 badges computed from life list + journal (`ns.BADGES`, `ns:BadgeProgress`, `ns:CheckBadges`); earned dates in `db.badges` |
| UIKit.lua | Shared UI helpers `ns.UI`: buttons, labels, scrolling lists, call buttons, text box, colours, book status line |
| Toast.lua | Queued pop-ups: new species ("Lifer!"), new kind, rare bird, badge earned, buddy's lifer; "Spot" button |
| MapPins.lua | World map pins on the map canvas for tracked birds (`db.pins`) or every bird in the viewed zone (`pinsAll`); zone name -> uiMapID by walking `C_Map.GetMapChildrenInfo` |
| Tooltip.lua | Birdsong line in unit tooltips (`TooltipDataProcessor`, fallback `OnTooltipSetUnit`) |
| Model.lua | `ns:CreateModelView` – PlayerModel box: `SetDisplayInfo(displayID)`, falls back to `SetCreature(npcID)`; drag to turn, wheel to zoom, optional slow spin |
| Book.lua | The book window, 7 tabs: Field Guide, Atlas (zones → kinds → model, calls, map, spot), Zones (soundscape, music, credits), Journal, Badges, Soundscapes, Settings |
| Settings.lua | `ns:BuildSettingsPanel(parent)` for the Settings tab (two columns); Blizzard Options → AddOns has a pointer page; reset confirm popup |
| Minimap.lua | Draggable minimap button (left: book, right: settings) |

## Key decisions (and why)
- **Play game files by FileDataID, never ship audio:** no copyright issue, tiny add-on. Sound IDs came from `github.com/wowdev/wow-listfile` (folders `sound/creature/<bird>/`, `sound/doodad/fx_owl0*`, `sound/ambience/zoneambience/`).
- **Recognise birds by creature ID** (from the unit GUID) against the Atlas; whole-word name matching is only the fallback for creatures not in the Atlas (later-lands birds, pets). Humanoid/Undead and players are skipped.
- **Atlas data** comes from two open-source projects, parsed as text and never executed: cmangos classic-db (`creature_template`: name, levels, family 7/12/26 = carrion bird/tallstrider/owl, model IDs) and pfQuest (`db/units.lua` spawn zones, `db/enUS/zones.lua`). Parrots, chickens, gryphons and hippogryphs have no pet family, so they're picked by name. Creatures with no spawns are dropped, as are the flight-path event birds 9526/9527. To regenerate: clone both repos into a scratch folder, `zcat` the cmangos Full_DB SQL to `full.sql`, then run `tools/parse.py`, `tools/birds_db.py`, `tools/gen_atlas.py > Atlas.lua`.
- **Discoveries:** a bird matched by name but missing from the Atlas data is saved in `db.found[npcID]` and added to `ns.KINDS` (flag `found`, no display ID, so the model uses `SetCreature`). It counts like any kind; its zones and level range grow as you see it. Buddy bitmasks use only the shipped Atlas (`ns.ATLAS_KIND_COUNT`). Harry's first ones: Green Wing Macaw, Prairie Chicken (worth adding to the Atlas data properly).
- **Models by display ID** (works without having seen the creature); creature ID fallback.
- **Rares** = cmangos Rank 2 (rare elite) or 4 (rare): 8 birds.
- **Binoculars emote only from a click or /birds spot** (never automatic): chat from add-ons is restricted under Midnight.
- **Buddy is mutual and private:** both set each other; messages from anyone else are ignored; only the life list bitmask and lifer IDs are sent. Wire format is append-only. A different Atlas size means "different version": no ticks shown rather than wrong ones.
- **Zone notes:** soundscape + music theme per zone are best guesses (labelled in the UI). Credits only from a source: Engadget 2007 (most of the soundtrack by Jason Hayes, with Glenn Stafford and Tracy W. Bush; Hayes wrote the Ironforge theme).
- **Out of combat only:** fits the Midnight rules (show information, don't decide things in combat).
- Soundscape → zone lists are best guesses to check in-game.
- **Later-lands birds (seagull, raven, stormcrow, turkey, tickbird)** are listed but may be missing from the Forever client; the book says so if a sound won't play.
- **No invented credits.** Zone sound/art credits (v0.3) only where a source exists, cited.
- **Not South African themed** (Harry's call): neutral, field-guide tone.

## Open questions to check in a play-test
- Do all native sounds play in the Forever client? Which later-lands sounds are missing?
- Do the 3D models show for every Atlas kind (classic display IDs on the Forever client)?
- Does the Atlas zone list match what's in Forever (any missing birds)?
- Does the soundscape-to-zone mapping match what you hear?
- Does `UnitCreatureType` return "Beast"/"Critter" for birds and "Humanoid" for flight masters?
- Do map pins land in the right place, and does the zone-name lookup find Forever's map IDs?
- Does the tooltip line show (TooltipDataProcessor on the Forever client)?
- Buddy: does it work cross-realm via Battle.net, and same-realm via whisper?

## Conventions
- **Every change:** bump `## Version` in both TOCs and `ns.VERSION`; add a CHANGELOG entry; run `python3 tests/run_tests.py`. Once on GitHub, pushing a new version *is* the release (playbook section 6).
- Add new files to both TOCs, and give every feature a check in `tests/smoke.lua`.
- Guard modern APIs, pcall risky calls, check `ns.IsSecret`. Pop-ups never echo to chat by default.

## Roadmap
1. **v0.1 Field guide (done):** book, real calls, soundscapes, life list, new-species pop-up.
2. **v0.2 Atlas (done):** every classic bird by zone, 3D models, creature-ID sightings, kinds in the life list, tab rework, settings, minimap button.
3. **v0.3 (this build):** map pins, rares, tooltip line, binoculars emote, journal, badges, birding buddy, zone notes.
4. **Maybe:** BirdNET analysis of soundscape loops to name the real-world birds in them (Harry: "later, if at all").
5. **Next:** publish to GitHub (Radewest/birdsong) + CurseForge so Harry's friend can install it.
