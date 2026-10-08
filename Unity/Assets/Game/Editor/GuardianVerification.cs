using System;
using System.Collections.Generic;
using System.IO;
using Newtonsoft.Json.Linq;

namespace Eternal.UnityMigration.Editor
{
    public static class GuardianVerification
    {
        sealed class Tape : System.Random
        {
            readonly Queue<int> draws=new();
            public int Remaining=>draws.Count;
            public Tape(JArray values){foreach(int value in values)draws.Enqueue(value);}
            public override int Next(int low,int high)
            {if(draws.Count==0)throw new InvalidOperationException("Unexpected summon RNG draw.");int value=draws.Dequeue();if(value<low||value>=high)throw new InvalidOperationException("Summon RNG interval differs from original.");return value;}
        }
        public static JObject Verify()
        {
            var fixture=JObject.Parse(File.ReadAllText("../checks/unity-migration-2026-10-08/guardian-original-fixtures.json"));
            var catalog=new OriginalCombatCatalog(OriginalCatalog.Required("hero-catalog").text);int comparisons=0,guardians=0,heroes=0,pets=0;
            foreach(JObject row in fixture["cases"])
            {
                int saves=0;var state=new GameStateCommands(catalog,(JObject)row["before"],_=>{saves++;return true;});StateCommandResult result;
                string type=(string)row["type"];
                if(type=="pet")
                {result=state.AwardPetXp((int)row["amount"]);if(result.Ok!=((int)row["amount"]>0))throw new InvalidOperationException("Pet XP rejection differs.");pets++;}
                else
                {
                    var tape=new Tape((JArray)row["random_tape"]);result=type=="guardian"?state.SummonGuardian(tape):state.SummonHero(tape);
                    if(!result.Ok||saves!=(int)row["saves"]||tape.Remaining!=0)throw new InvalidOperationException("Original summon commit or RNG draw count differs.");comparisons+=3;
                    foreach(var property in ((JObject)row["result"]).Properties())
                    {if(LegacySaveCodec.Canonical(result.Details[property.Name])!=LegacySaveCodec.Canonical(property.Value))throw new InvalidOperationException("Original summon result differs: "+type+" / "+property.Name);comparisons++;}
                    if(type=="guardian")guardians++;else heroes++;
                }
                var actual=state.Snapshot();foreach(var property in ((JObject)row["after"]).Properties())
                {if(LegacySaveCodec.Canonical(actual[property.Name])!=LegacySaveCodec.Canonical(property.Value))throw new InvalidOperationException("Original guardian/hero progression differs: "+type+" / "+property.Name+" actual="+actual[property.Name]+" expected="+property.Value);comparisons++;}
            }
            // Boundary checks use one state owner and never replay a draw after
            // a failed save. Their expected behavior is atomic command safety.
            var blocked=(JObject)((JArray)fixture["cases"])[0]["before"].DeepClone();blocked["guardian_free_claimed"]=true;blocked["wallet_gems"]=79;
            int writes=0;var poor=new GameStateCommands(catalog,blocked,_=>{writes++;return true;});string before=poor.Snapshot().ToString();
            if(poor.SummonGuardian(new Tape(new JArray())).Ok||poor.SummonHero(new Tape(new JArray())).Ok||poor.Snapshot().ToString()!=before||writes!=0)throw new InvalidOperationException("Insufficient summon currency was consumed or saved.");comparisons+=4;
            var report=new JObject{{"passed",true},{"comparisons",comparisons},{"guardian_production_cases",guardians},{"hero_production_cases",heroes},{"pet_xp_production_cases",pets},{"source_random_outputs_replayed",true},{"pcg_stream_migrated",false},{"real_player_io",false},{"note","Production services are executed on healthy isolated snapshots, including free/purchased draws, both pity boundaries, duplicate caps and pet levels/evolution. Recorded Godot RNG draws verify selection and state results; Unity System.Random does not reproduce a saved Godot PCG stream. Pet XP helper state is compared, not its enclosing reward/save workflow."}};
            File.WriteAllText("../checks/unity-migration-2026-10-08/guardian-progression.json",report.ToString());return report;
        }
    }
}
