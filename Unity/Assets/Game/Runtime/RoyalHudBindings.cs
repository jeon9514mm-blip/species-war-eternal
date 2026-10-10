using System;

namespace Eternal.UnityMigration
{
    // The photographed Unity HUD can read any native combat session. It owns
    // presentation and input only; the game controller keeps reward/save authority.
    public sealed class RoyalHudBindings
    {
        public Func<CombatEncounter> Battle;
        public Func<bool> Paused, Finished, Defeated, ManualMovement, InputAllowed, OverlayBlocking, ZoomVisible;
        public Func<string,string,bool> CanCast;
        public Func<string> Stage, Progress;
        public Action<string> Navigate;
        public Action Manage;
    }
}
