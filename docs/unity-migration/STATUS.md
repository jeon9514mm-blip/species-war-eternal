# Unity migration — checkpoint 2026-10-08

This checkpoint verifies the new engine connection and original asset import. It is **not a completed gameplay conversion**.

## Preserved direction

- Same world, stable hero/save IDs, 30 original painted heroes and 120 existing skill definitions.
- Ten-member parties, progression, factions, hunting areas and three existing raid identities.
- Original-painted 2.5D with a 45-degree camera. Do not replace this with a generic single-character or pixel game.
- Preserve old game/source and old player saves until the Unity parity checklist passes. Do not overwrite Godot saves with a new Unity schema.
- User authorizes migration, installation, testing and GitHub default-branch updates without repeated confirmation.
- Requested review deadline: 2026-10-09 08:00 Asia/Seoul. Report actual tested scope and incomplete features honestly at the deadline.

## Verified

- Unity 6000.6.4f1 installed through Hub; OAuth and Unity Personal active.
- Repository project: `Unity/`, Universal 3D / URP 17.6.0.
- `com.unity.pipeline` 0.8.0-exp.1 controls the repository's own Editor, ready on localhost.
- C# compiled with zero compiler errors/warnings.
- Original asset importer copied 294 files without pixel changes: 46 actor atlases/metadata/relief sources, floor maps, 120 skill audio files, common audio and Outfit font. Import provenance is `checks/unity-migration-2026-10-08/original-import.json`.
- Asset verification scene animated all 46 actors, including 30 heroes and three bosses. Frame counter advanced from 2326 to 2333 in 120ms; review controller reached frame 2347. This proves rendering ticks, not game performance at 60fps.
- Saved native Unity capture: `Unity/Assets/Screenshots/original-assets.png`.
- Inspection showed original colour/alpha, no black silhouettes in this review. This does not prove all gameplay/material states are fixed.
- Console inspection: no game exceptions/compile errors during the review. Two earlier Pipeline command errors remain in history: the first import exceeded eval's default 5000ms while its import completed successfully, and this package lacks `editor_set_run_in_background`. Longer eval timeout and the documented `Application.runInBackground` fallback were then used successfully. Previous background setting was restored after Play mode.

## Open / implement next

1. Export canonical zone, raid pattern, guardian, equipment, progression and persistence data without changing IDs. Existing hero JSON retains all skill fields, but the first review DTO only exposes basic display fields; expand it before combat.
2. Port C# gameplay: fixed-step simulation with render interpolation; attack windup, cooldowns, targeting, all skill/passive conditions and statuses; 10-hero formations, projected body separation, multiple monster entrances/flocking. Prevent damage/time-scale feedback from repeatedly freezing combat.
3. Port wallet/claim/progression/equipment/summon/guardian systems, five navigation routes and all real menu destinations. No fake buttons or duplicate background combat loops.
4. Separate, read-only legacy save import with version and corruption guards; isolated fixture save paths for tests. Retain backup and never credit raid/claims twice.
5. Three dedicated raid arenas with existing identities and patterns; ground telegraphs, counter/stagger windows, movement/dodge/rally, shield/add/DPS mechanics, 240s timeout and 180s enrage. Depth/body clearance and camera must remain stable.
6. Original art billboards first, then verified relief geometry/hair/cloth port. Current preview uses camera-facing alpha quads; GLB sources are imported as bytes and **not yet rendered as meshes**. Hair/cloth/SSS/Ultra requests are pending, not achieved by file copy.
7. Distinct skill VFX/audio for all existing skills, bounded pools and mobile quality budgets. Preserve floor PBR, moss/bronze/runes; use stronger feedback sparingly so the prior stutter issue does not return.
8. Review Korean UI typography, readability, simple growth/loot flows; retain original game configuration.
9. Verify live hunting/raid/input/progression/rewards and a real standalone build, plus clean checkout/reimport. Ensure runtime-created shader/materials are included in build (Shader.Find alone is insufficient).
10. Profile target hardware, worst-case hunt and raid; publish native screenshots/performance results. Do not claim 60fps/200MB or visual parity without measured evidence.
11. Make Unity the primary launch path only after playable parity. Keep old source as history/reference; do not declare the engine switched just because a blank URP project exists.

## Asset import / review

Open `Unity/` with the pinned editor. Use **Eternal > Import original assets**, then **Eternal > Create asset verification scene**, then Play. Generated `Assets/OriginalImported/` is ignored to avoid duplicating assets already tracked in the repository; the importer rebuilds it from those source files. Imports never read player save files. Scene/material changes should use the running Editor's Pipeline / UnityEditor APIs, not handwritten YAML.

CLI binary for this workstation lives outside the repository at `validation/unity/cli/bin/unity.exe` (workspace root). Skill docs: `validation/unity/.agents/skills/unity-cli/SKILL.md`. Always select the exact `species-war-eternal/Unity` project; another open Editor is the user's tutorial project and must not be used.

For bulk eval, set both the CLI timeout (seconds) and the Editor eval timeout (milliseconds), separated by `--`. Set autotick before Play, use the documented background fallback if this package still lacks its dedicated command, prove frameCount changes, inspect console, capture `source=screen`. This package saved `Screenshots/...` under `Assets/Screenshots/`.

## Reference research status

- CookieRun growing game identified as **CookieRun: Crumble / 쿠키런: 크럼블**, not Kingdom/Tower of Adventures. Official design source: https://www.devsisters.com/stories/news/CC-global-launch . Official channel: https://www.youtube.com/@CookieRunCrumble . Actual official video located: https://www.youtube.com/watch?v=jmbR4gP5e1s . In-app browser reported media unavailable; **do not claim it was watched**. Use an available browser/player and observe actual frames.
- Soul Strike official: https://event.com2us.com/ci/soulstrike/brand . Official gameplay video observations pending.
- Lost Ark official raid telegraph/counter/stagger guide and actual video observations pending. Adapt readability/counterplay to this ten-hero game; do not introduce MMO infrastructure.
- Pixel Wizard growing game official press source: https://www.onestorecorp.com/news/presskit/2024/2024-10-29.html . Skill chaining is a referenced feature. Located video: https://www.youtube.com/watch?v=IezjzrgBH40 ; not yet watched/validated.

## Publication

Before a checkpoint completes, publish its source, native scene/settings and selected review artifacts to GitHub default branch `jeon9514mm-blip/species-war-eternal`, verify remote tree, and report the actual milestone. Preserve paused black-render diagnostics; they are untracked from the stopped Godot task and must not be accidentally staged as Unity production work.
