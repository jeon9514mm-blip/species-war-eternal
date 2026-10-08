#if UNITY_EDITOR || DEBUG
using System;
using System.Linq;
using Newtonsoft.Json.Linq;
using UnityEngine;
using UnityEngine.UIElements;

namespace Eternal.UnityMigration.Editor
{
    // Read-only observation for an external Input System acceptance driver.
    // This class never invokes a callback, advances combat or changes state.
    public static class NativeUiVerification
    {
        public static string Inspect()
        {
            if(!Application.isPlaying)throw new InvalidOperationException("UI observation requires native Play mode.");
            var review=UnityEngine.Object.FindAnyObjectByType<HuntingMigrationReview>();var ui=review?.GetComponent<UIDocument>()?.rootVisualElement;
            if(ui==null)throw new InvalidOperationException("Native review UI is unavailable.");var buttons=new JArray();
            foreach(var button in ui.Query<Button>().ToList())
            {
                var bounds=button.worldBound;bool visible=button.visible&&bounds.width>0&&bounds.height>0&&ui.worldBound.Contains(bounds.center);
                for(VisualElement parent=button;parent!=null;parent=parent.parent)
                {
                    if(parent.resolvedStyle.display==DisplayStyle.None||parent.resolvedStyle.visibility==Visibility.Hidden)visible=false;
                    if(parent is ScrollView scroll&&!scroll.contentViewport.worldBound.Contains(bounds.center))visible=false;
                }
                if(!visible)continue;
                var labels=button.Query<Label>().ToList().Select(l=>l.text).Where(s=>!string.IsNullOrWhiteSpace(s));
                buttons.Add(new JObject{{"text",button.text??""},{"labels",new JArray(labels)},{"data",button.userData is string id?id:""},{"enabled",button.enabledInHierarchy},{"x",bounds.center.x/ui.worldBound.width*Screen.width},{"y",(1-bounds.center.y/ui.worldBound.height)*Screen.height}});
            }
            var state=review.ReviewState;var growth=new JObject();
            foreach(string id in state.DeployedHeroes())
            {
                var progress=state.HeroProgress(id);var tree=state.HeroTree(id);var actor=review.Simulation.Battle.Heroes.First(a=>a.Id==id);
                growth[id]=new JObject{{"level",progress.level},{"offense",tree.offense},{"survival",tree.survival},{"utility",tree.utility},{"available",tree.available},{"grade",state.Grade(id)},{"attack",actor.Attack},{"max_hp",actor.MaxHp},{"hp",actor.Hp},{"equipment_power",state.EquipmentPower(id)}};
            }
            var report=new JObject{{"frame",Time.frameCount},{"screen_width",Screen.width},{"screen_height",Screen.height},{"buttons",buttons},{"wallet_gold",state.WalletGold},{"wallet_gems",state.WalletGems},{"inventory",new JArray(state.Inventory())},{"heroes",growth},{"mode",review.Raid==null?"hunt":"raid"},{"hunt_packs",review.Simulation.PacksCleared},{"hunt_ticks",review.Simulation.Ticks},{"raid_ticks",review.Raid?.Ticks??0},{"raid_zone",review.Raid?.Zone??""},{"raid_outcome",review.Raid?.Outcome??""},{"raid_dodge_cooldown",review.Raid?.DodgeCooldown??0},{"raid_counter_ready",review.Raid?.CounterReady??false},{"raid_counter_successes",review.Raid?.CounterSuccesses??0},{"chain_enabled",(review.Raid?.Chain??review.Simulation.Chain).Enabled},{"chain",new JArray((review.Raid?.Chain??review.Simulation.Chain).Entries.Select(e=>e.Hero+":"+e.Slot))},{"note","Read-only snapshot. External actual pointer input supplies action evidence; this method invokes no UI callbacks."}};
            return report.ToString();
        }
    }
}
#endif
