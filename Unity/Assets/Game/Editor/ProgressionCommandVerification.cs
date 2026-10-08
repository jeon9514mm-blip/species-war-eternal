using System;
using System.Collections.Generic;
using System.IO;
using Newtonsoft.Json.Linq;

namespace Eternal.UnityMigration.Editor
{
    public static class ProgressionCommandVerification
    {
        public static JObject Verify()
        {
            var oracle=JObject.Parse(File.ReadAllText("Assets/Game/Editor/Fixtures/progression-command-fixtures.json"));
            var catalog=new OriginalCombatCatalog(OriginalCatalog.Required("hero-catalog").text);int comparisons=0;var counts=new Dictionary<string,int>();
            foreach(JObject row in oracle["cases"])
            {
                string command=(string)row["command"],hero=(string)row["hero"];
                var before=(JObject)row["before"];string original=before.ToString();var state=new GameStateCommands(catalog,before,_=>true);
                StateCommandResult result=command switch
                {
                    "xp"=>state.AwardHeroXp((int)row["amount"]),
                    "ascend"=>state.Ascend(hero),
                    "research"=>state.UpgradeResearch(hero,(string)row["branch"]),
                    "breakthrough"=>state.Breakthrough(hero),
                    "daily"=>state.ClaimDaily((string)row["day"]),
                    "support"=>state.ClaimSupport((string)row["day"]),
                    "claim"=>state.ClaimHuntingRewards(),
                    _=>throw new InvalidOperationException("Unknown progression fixture")
                };
                var actual=state.Snapshot();var expected=(JObject)row["after"];
                foreach(var property in expected.Properties())
                {
                    comparisons++;
                    if(LegacySaveCodec.Canonical(actual[property.Name])!=LegacySaveCodec.Canonical(property.Value))
                        throw new InvalidOperationException("Progression "+command+" "+hero+" "+property.Name+": "+actual[property.Name]+" != "+property.Value);
                }
                comparisons++;if(before.ToString()!=original)throw new InvalidOperationException("State owner mutated caller payload.");
                if(row["ok"]!=null){comparisons++;if(result.Ok!=(bool)row["ok"])throw new InvalidOperationException("Progression success guard changed: "+command+" "+hero);}
                if(row["grade"]!=null){comparisons++;if(state.Grade(hero)!=(string)row["grade"])throw new InvalidOperationException("Original faction grade order changed.");}
                counts[command]=counts.GetValueOrDefault(command)+1;
            }
            // Failed disk writes retain awarded state; retry only its snapshot.
            var initial=(JObject)oracle["cases"][0]["before"];bool allowWrite=false;int writes=0;
            var retained=new GameStateCommands(catalog,initial,_=>{writes++;return allowWrite;});
            long gold=retained.WalletGold;var claim=retained.ClaimHuntingRewards();
            if(!claim.Ok||!claim.SavePending||retained.WalletGold!=gold+150)throw new InvalidOperationException("Award disappeared on storage failure.");comparisons+=3;
            int firstWrites=writes;var blocked=retained.ClaimHuntingRewards();
            if(blocked.Ok||writes!=firstWrites||retained.WalletGold!=gold+150)throw new InvalidOperationException("Pending award replayed.");comparisons+=3;
            allowWrite=true;if(!retained.RetrySave()||retained.SavePending||retained.WalletGold!=gold+150)throw new InvalidOperationException("Retry reapplied reward instead of storing snapshot.");comparisons+=3;
            if(retained.ClaimHuntingRewards().Ok)throw new InvalidOperationException("Empty reward could be claimed twice.");comparisons++;
            var future=new GameStateCommands(catalog,initial,_=>true,true);
            if(future.ClaimDaily("2026-10-09").Ok||future.WalletGems!=0)throw new InvalidOperationException("Future-version mutation allowed.");comparisons+=2;
            var practice=new GameStateCommands(catalog,initial,_=>true){PracticeActive=true};
            if(practice.ClaimDaily("2026-10-09").Ok||practice.WalletGems!=0)throw new InvalidOperationException("Practice changed persistent wallet.");comparisons+=2;
            var malformed=new GameStateCommands(catalog,new JObject{{"selected_faction","aurelia"},{"hero_progress","broken"},{"hero_skill_tree","broken"},{"hero_ascension","broken"}},_=>true);
            if(malformed.HeroProgress("leonhardt")!=(1,0)||malformed.HeroTree("leonhardt")!=(0,0,0,0)||malformed.Grade("leonhardt")!="R")throw new InvalidOperationException("Malformed known maps broke read-only growth inspection.");comparisons+=3;
            var newerPayload=(JObject)initial.DeepClone();newerPayload["save_version"]=38;
            var newer=new GameStateCommands(catalog,newerPayload,_=>true);
            if(!newer.FutureVersionBlocked||newer.ClaimDaily("2026-10-09").Ok)throw new InvalidOperationException("Higher source version depended on caller remembering its guard.");comparisons+=2;
            var report=new JObject{{"passed",true},{"comparisons",comparisons},{"production_command_cases",((JArray)oracle["cases"]).Count},{"commands",JObject.FromObject(counts)},{"storage_failure_retains_state",true},{"retry_does_not_replay_rewards",true},{"note","Production progression/reward oracle with isolated snapshots; no real player IO, inventory/guardian completeness or live progression UI acceptance is implied."}};
            File.WriteAllText("../checks/unity-migration-2026-10-08/progression-commands.json",report.ToString());return report;
        }
    }
}
