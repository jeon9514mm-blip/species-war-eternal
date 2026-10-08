using System;
using System.Collections.Generic;
using System.IO;
using Newtonsoft.Json.Linq;
using UnityEngine;

namespace Eternal.UnityMigration.Editor
{
    public static class SkillExecutionVerification
    {
        public static string Verify()
        {
            var catalog=new OriginalCombatCatalog(OriginalCatalog.Required("hero-catalog").text);
            var cases=(JArray)JObject.Parse(OriginalCatalog.Required("skill-execution-fixtures").text)["cases"];
            int comparisons=0;var failures=new List<string>();
            foreach(JObject c in cases)
            {
                string id=(string)c["hero"],slot=(string)c["slot"];int scenario=(int)c["scenario"];
                var battle=new CombatEncounter();var data=catalog.Hero(id);var identity=(JObject)data["identity_profile"];
                for(int i=0;i<4;i++)
                {
                    var a=new Combatant{Id=i==0?id:"fixture_ally_"+i,Serial=i+1,Hp=scenario==1?1000:i==0?450:350+i*100,MaxHp=1000,Attack=200,Defense=10,Slot=i,Range=3,Row=i<2?"front":"rear",Role=i==0?(string)data["role_group"]:"딜러",Ultimate=100,Guard=scenario==2?1:0,UltimateGainMultiplier=i==0?LegacyCombatRules.Number(identity,"ult_gain_mult",1):1};
                    battle.Heroes.Add(a);
                }
                var hero=battle.Heroes[0];var kit=new HeroKitState(catalog,id,0,new Vector2(-1,0)){BasicCount=3};battle.Kits[id]=kit;
                for(int i=0;i<3;i++)battle.Enemies.Add(new Combatant{Id="fixture_enemy_"+i,Serial=100+i,Hp=scenario!=2?1000:i==0?1:350,MaxHp=1000,Attack=80,Slot=i,Elite=i==2,TargetId=id,Weaken=scenario==2?1:0});
                int total=0;battle.OnEvent=e=>{if(e.Kind=="damage"||e.Kind=="critical")total+=e.Amount;};
                string context=id+"/"+slot+"/"+scenario;
                void Compare(string key,double actual,double expected)
                {
                    comparisons++;if(Math.Abs(actual-expected)>Math.Max(.00001,Math.Abs(expected)*.00001))failures.Add(context+" "+key+" Unity="+actual+" original="+expected);
                }
                Compare("can_use",HeroKitExecution.CanUse(battle,hero,slot)?1:0,(bool)c["can_use"]?1:0);
                HeroKitExecution.Cast(battle,hero,slot,battle.Enemies[0]);Compare("damage",total,(double)c["damage"]);
                foreach(var a in battle.Heroes)
                {
                    var expected=(JObject)c["heroes"][a.Id];
                    Compare(a.Id+" hp",a.Hp,(double)expected["hp"]);Compare(a.Id+" shield",a.Shield,(double)expected["shield"]);
                    Compare(a.Id+" shield_seconds",a.ShieldSeconds,(double)expected["shield_seconds"]);
                    Compare(a.Id+" guard",a.Guard,(double)expected["guard"]);Compare(a.Id+" taunt",a.Taunt,(double)expected["taunt"]);
                    Compare(a.Id+" ultimate",a.Ultimate,(double)expected["ultimate"]);
                }
                for(int i=0;i<3;i++)
                {
                    var enemy=battle.Enemies[i];var expected=(JObject)c["enemies"][i];
                    Compare("enemy"+i+" hp",enemy.Hp,(double)expected["hp"]);
                    Compare("enemy"+i+" stun",enemy.Stun,(double)expected["stun_seconds"]);
                    Compare("enemy"+i+" weaken",enemy.Weaken,(double)expected["weaken_seconds"]);
                    Compare("enemy"+i+" vulnerable",enemy.Vulnerable,(double)expected["vulnerable_seconds"]);
                }
                var runtime=(JObject)c["runtime"];
                Compare("a1 cooldown",kit.Cooldowns.GetValueOrDefault("a1"),LegacyCombatRules.Number(runtime,"remaining"));
                Compare("a2 cooldown",kit.Cooldowns.GetValueOrDefault("a2"),LegacyCombatRules.Number(runtime,"secondary_remaining"));
                Compare("passive cooldown",kit.PassiveRemaining,LegacyCombatRules.Number(runtime,"passive_remaining"));
                Compare("passive count",kit.PassiveCount,LegacyCombatRules.Number(runtime,"passive_count"));
                Compare("passive procs",kit.PassiveProcs,LegacyCombatRules.Number(runtime,"passive_procs"));
                Compare("casts",kit.Casts.GetValueOrDefault(slot),LegacyCombatRules.Number(runtime,"casts_"+slot));
            }
            var report=new JObject{{"passed",failures.Count==0},{"scenarios",cases.Count},{"comparisons",comparisons},{"failures",new JArray(failures)}};
            Directory.CreateDirectory("../checks/unity-migration-2026-10-08");File.WriteAllText("../checks/unity-migration-2026-10-08/skill-execution-parity.json",report.ToString());
            if(failures.Count>0)throw new InvalidOperationException("Original runtime parity failed: "+failures.Count+"\n"+string.Join("\n",failures.GetRange(0,Math.Min(20,failures.Count))));
            return report.ToString();
        }
    }
}
