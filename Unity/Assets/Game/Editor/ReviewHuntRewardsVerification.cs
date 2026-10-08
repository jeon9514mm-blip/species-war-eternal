using System;
using System.IO;
using System.Linq;
using Newtonsoft.Json.Linq;

namespace Eternal.UnityMigration.Editor
{
    public static class ReviewHuntRewardsVerification
    {
        public static string Verify()
        {
            var catalog=new OriginalCombatCatalog(OriginalCatalog.Required("hero-catalog").text);int checks=0,writes=0;
            void Check(bool value,string label){checks++;if(!value)throw new InvalidOperationException("Unity preview reward: "+label);}
            var seed=ReviewStateFixture.Create(catalog);var state=new GameStateCommands(catalog,seed,_=>{writes++;return true;});long before=state.WalletGold;
            Check(state.SettleReviewHuntPack(1,90,90).Ok,"first pack accepted");Check(state.WalletGold==before+90,"wallet credited");Check(writes==1,"one snapshot");
            Check(state.DeployedHeroes().Sum(id=>state.HeroProgress(id).xp)==90,"party receives xp");string settled=state.Snapshot().ToString();
            Check(!state.SettleReviewHuntPack(1,90,90).Ok,"duplicate rejected");Check(state.Snapshot().ToString()==settled&&writes==1,"duplicate preserves wallet and state");
            Check(!state.SettleReviewHuntPack(3,90,90).Ok,"skipped sequence rejected");Check(!state.SettleReviewHuntPack(2,-1,90).Ok,"negative award rejected");
            Check(state.SettleReviewHuntPack(2,110,60).Ok,"next pack accepted");Check(state.WalletGold==before+200&&writes==2,"consecutive exact credit");Check((int)state.Snapshot()["native_review_settled_pack"]==2,"settlement cursor");
            var real=(JObject)seed.DeepClone();real.Remove("native_review_fixture");var blocked=new GameStateCommands(catalog,real,_=>true);string intact=blocked.Snapshot().ToString();
            Check(!blocked.SettleReviewHuntPack(1,90,90).Ok,"actual payload rejected");Check(blocked.Snapshot().ToString()==intact,"actual payload untouched");
            var failed=new GameStateCommands(catalog,seed,_=>false);Check(failed.SettleReviewHuntPack(1,90,90).Ok&&failed.SavePending,"failed store retains credited snapshot");
            long credited=failed.WalletGold;Check(!failed.SettleReviewHuntPack(2,90,90).Ok&&failed.WalletGold==credited,"pending store blocks further award");
            Check(seed["native_review_settled_pack"]==null,"caller seed remains unchanged");
            var report=new JObject{{"passed",true},{"comparisons",checks},{"memory_only",true},{"real_player_io",false},{"note","New Unity preview settlement, not exhaustive Godot reward parity. Checks exact wallet/party XP, sequence/duplicate rejection, atomic snapshots, actual-payload exclusion and pending-store barrier."}};
            File.WriteAllText("../checks/unity-migration-2026-10-08/unity-review-hunt-rewards.json",report.ToString());return report.ToString();
        }
    }
}
