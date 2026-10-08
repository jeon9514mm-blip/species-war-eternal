using System;
using System.IO;
using System.Linq;
using Newtonsoft.Json.Linq;

namespace Eternal.UnityMigration.Editor
{
    public static class ReviewStateVerification
    {
        public static JObject Verify()
        {
            var catalog=new OriginalCombatCatalog(OriginalCatalog.Required("hero-catalog").text);var original=ReviewStateFixture.Create(catalog);string untouched=original.ToString();JObject stored=null;int saves=0,checks=0;
            var state=new GameStateCommands(catalog,original,snapshot=>{stored=snapshot;saves++;return true;});var sim=new HuntingSimulation(20,9514,state);
            if(sim.Battle.Heroes.Count!=10||sim.Battle.Heroes.Any(h=>state.HeroProgress(h.Id).level!=20)||state.Inventory().Count!=5)throw new InvalidOperationException("Native review seed roster/level/inventory changed.");checks+=3;
            string before=state.Snapshot().ToString();for(int i=0;i<1200;i++)sim.Step(.05);
            if(sim.PacksCleared<2||sim.Gold==0||state.Snapshot().ToString()!=before||saves!=0)throw new InvalidOperationException("Review hunting stalled or unexpectedly credited the persistent state: packs="+sim.PacksCleared+" kills="+sim.Kills+" snapshot_changed="+(state.Snapshot().ToString()!=before)+" saves="+saves);checks+=4;
            var actor=sim.Battle.Heroes.First(h=>h.Id=="leonhardt");int oldAttack=actor.Attack;double ratio=actor.HpRatio;var kit=sim.Battle.Kits[actor.Id];kit.Cooldowns["a1"]=4.5;int oldBag=state.Inventory().Count;
            var best=state.RecommendEquip();if(!best.Ok)throw new InvalidOperationException("Native review recommendation failed.");sim.RefreshHeroGrowth();
            if(actor.Attack<=oldAttack||state.Inventory().Count!=oldBag||kit.Cooldowns["a1"]!=4.5||Math.Abs(actor.HpRatio-ratio)>1d/actor.MaxHp)throw new InvalidOperationException("Native review equipment did not refresh the same live hero safely.");checks+=4;
            if(!state.UpgradeResearch(actor.Id,"utility").Ok||!state.Ascend(actor.Id).Ok||!state.Breakthrough(actor.Id).Ok)throw new InvalidOperationException("Native review growth commands failed.");sim.RefreshHeroGrowth();
            if(kit.Utility!=1||state.Grade(actor.Id)!="SR"||(int)state.Snapshot()["hero_breakthrough"][actor.Id]!=1)throw new InvalidOperationException("Native review growth did not retain state.");checks+=6;
            long wallet=state.WalletGold;var first=state.ClaimHuntingRewards();var second=state.ClaimHuntingRewards();
            if(!first.Ok||second.Ok||first.Gold!=500||first.Xp!=250||state.WalletGold!=wallet+500)throw new InvalidOperationException("Native review rewards were duplicated.");checks+=5;
            if(!state.ClaimDaily("2026-10-09").Ok||state.ClaimDaily("2026-10-09").Ok||state.WalletGems!=130)throw new InvalidOperationException("Native review daily reward guard failed.");checks+=3;
            if(stored==null||LegacySaveCodec.Canonical(stored)!=LegacySaveCodec.Canonical(state.Snapshot())||saves!=6||original.ToString()!=untouched)throw new InvalidOperationException("Native review memory snapshot diverged or modified its seed.");checks+=4;
            var report=new JObject{{"passed",true},{"comparisons",checks},{"simulated_seconds",sim.Elapsed},{"hunt_packs",sim.PacksCleared},{"commands_saved_in_memory",saves},{"native_seed_preserved",true},{"no_file_io",true},{"note","Isolated runtime seed/session command integration. UI layout and pointer input require separate native review; no player-save persistence or full hunting rewards implied."}};
            File.WriteAllText("../checks/unity-migration-2026-10-08/review-state-session.json",report.ToString());return report;
        }
    }
}
