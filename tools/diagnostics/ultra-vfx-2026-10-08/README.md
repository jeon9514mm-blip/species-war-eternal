# Native Ultra skill showcase

`run_native_ultra_skill_showcase.py` launches the real `PortraitMain.tscn` through Godot Mobile renderer with a disposable save/preferences directory. It writes native root-viewport PNGs and `showcase-fixture.json` to `checks/ultra-vfx-2026-10-08/showcase` by default.

The roster has two actual factions with fifteen heroes each. Four permitted same-faction lineups cover all thirty heroes: Aurelia core ten/reserve five and Noxfera core ten/reserve five. No third faction or mixed player party is invented.

All ninety active/ultimate identities are invoked through the real `HeroKitRuntime.cast` with explicitly prepared living high-HP targets, wounded allies, ready cooldowns and full review-fixture ultimate meters. A separate set of thirty passive visual fixtures uses the actual registered passive profiles and the real presentation observer with an explicitly incremented fixture serial. These images are not evidence of naturally occurring passive conditions; `UltraSkillRouterSmokeTest.gd` separately exercises a real confirmed guarded passive, a failed condition and cooldown suppression.

Each lineup captures six representative native phases—charge, flight, impact, trail, afterglow and fade—and one separately labeled passive fixture, twenty-eight PNGs in total. Simulation/timers and the contact-time-dilation feature are disabled while the presenters advance manually. Native GPU particles still render in the live renderer. Fixture levels/wallet/HP values are never player-save modifications.

This runner performs no FPS benchmark. Its memory fields are diagnostic snapshots during screenshot fixtures; use the separate production timing measurement for performance claims. PNG extraction and image saving are outside that measurement.

Run after Godot import and coordinated GPU validation:

```powershell
python tools/diagnostics/ultra-vfx-2026-10-08/run_native_ultra_skill_showcase.py
```
