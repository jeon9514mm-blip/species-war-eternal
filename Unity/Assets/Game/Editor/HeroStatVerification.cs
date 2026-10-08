using System;
using System.IO;
using System.Collections.Generic;
using System.Linq;
using Newtonsoft.Json.Linq;
using UnityEngine;

namespace Eternal.UnityMigration.Editor
{
    public static class HeroStatVerification
    {
        public static JObject Verify()
        {
            var fixture=JObject.Parse(File.ReadAllText("Assets/Game/Editor/Fixtures/hero-stat-fixtures.json"));var catalog=new OriginalCombatCatalog(OriginalCatalog.Required("hero-catalog").text);
            int comparisons=0;var heroes=new HashSet<string>(StringComparer.Ordinal);
            foreach(JObject row in fixture["cases"])
            {
                string id=(string)row["hero"];heroes.Add(id);var state=new GameStateCommands(catalog,(JObject)row["before"],_=>true);string before=state.Snapshot().ToString();
                var profile=state.CombatProfile(id,(int)row["slot"]);Compare(profile,(JObject)row["expected"],id,ref comparisons);
                Compare(state.PartySynergy(),(JObject)row["synergy"],id+" party",ref comparisons);
                if(state.Snapshot().ToString()!=before)throw new InvalidOperationException("Combat profile query mutated the state: "+id);comparisons++;
                var actor=new Combatant{Id=id,Hp=3,MaxHp=10,Shield=14,ShieldSeconds=1.1,Guard=2.3,Taunt=3.2,Stun=.4,Weaken=.8,Vulnerable=1.5,Ultimate=37,Windup=.18,AttackRemaining=.7,Position=new Vector2(1,2),PreviousPosition=new Vector2(.8f,1.9f),Velocity=new Vector2(.1f,.2f)};
                GameStateCommands.RefreshCombatant(actor,profile);
                if(actor.Hp!=Math.Max(1,(int)Math.Round((int)profile["max_hp"]*.3,MidpointRounding.AwayFromZero))||actor.MaxHp!=(int)profile["max_hp"]||actor.Attack!=(int)profile["attack"]||actor.Defense!=(int)profile["defense"])throw new InvalidOperationException("Growth refresh did not preserve HP proportion: "+id);comparisons+=4;
                if(actor.Shield!=14||actor.ShieldSeconds!=1.1||actor.Guard!=2.3||actor.Taunt!=3.2||actor.Stun!=.4||actor.Weaken!=.8||actor.Vulnerable!=1.5||actor.Ultimate!=37||actor.Windup!=.18||actor.AttackRemaining!=.7||actor.Position!=new Vector2(1,2)||actor.PreviousPosition!=new Vector2(.8f,1.9f)||actor.Velocity!=new Vector2(.1f,.2f))throw new InvalidOperationException("Growth refresh reset live battle state: "+id);comparisons+=13;
                actor.Hp=0;GameStateCommands.RefreshCombatant(actor,profile);if(actor.Alive)throw new InvalidOperationException("Growth refresh revived a defeated hero.");comparisons++;
            }
            if(heroes.Count!=30)throw new InvalidOperationException("Original combat profiles do not cover all 30 heroes.");
            var integration=VerifyHuntBinding(catalog,(JArray)fixture["cases"]);
            var report=new JObject{{"passed",true},{"comparisons",comparisons},{"original_heroes",heroes.Count},{"production_stat_cases",((JArray)fixture["cases"]).Count},{"growth_preserves_hp_ratio_and_live_status",true},{"read_only_queries",true},{"hunting_state_binding",integration},{"note","Production Main combat-stat oracle with original equipment/progression/guardian/formation/collection helpers, bound into native hunting. This does not complete player-save startup, hunt reward authority or all guardian combat actions."}};
            File.WriteAllText("../checks/unity-migration-2026-10-08/hero-combat-profiles.json",report.ToString());return report;
        }
        static JObject VerifyHuntBinding(OriginalCombatCatalog catalog,JArray cases)
        {
            int checks=0,saves=0,simulated=0;
            foreach(JObject row in cases)
            {
                string id=(string)row["hero"];int slot=(int)row["slot"];var payload=(JObject)row["before"].DeepClone();
                var ids=((JArray)payload["deployed_hero_ids"]).Values<string>().ToArray();int from=Array.IndexOf(ids,id);(ids[from],ids[slot])=(ids[slot],ids[from]);payload["deployed_hero_ids"]=new JArray(ids);
                var state=new GameStateCommands(catalog,payload,_=>{saves++;return true;});string snapshot=state.Snapshot().ToString();var sim=new HuntingSimulation(1,9514,state);
                var hero=sim.Battle.Heroes[slot];var expected=(JObject)row["expected"];
                if(hero.Id!=id||sim.Formation!=state.Formation||Math.Abs(sim.Battle.CriticalChance-state.GuardianBonus("crit"))>1e-9||!sim.Battle.Heroes.Select(a=>a.Id).SequenceEqual(ids))throw new InvalidOperationException("Hunting did not preserve the original deployed roster or formation.");checks+=4;
                Compare(new JObject{{"hp",hero.Hp},{"max_hp",hero.MaxHp},{"attack",hero.Attack},{"defense",hero.Defense},{"role_group",hero.Role},{"slot",hero.Slot},{"row",hero.Row},{"range",hero.Range},{"attack_interval_mult",hero.AttackIntervalMultiplier},{"ult_gain_mult",hero.UltimateGainMultiplier}},new JObject(expected.Properties().Where(p=>new[]{"hp","max_hp","attack","defense","role_group","slot","row","range","attack_interval_mult","ult_gain_mult"}.Contains(p.Name))),id+" hunting",ref checks);
                var kit=sim.Battle.Kits[id];int utility=(int)payload["hero_skill_tree"][id]["utility"];
                if(kit.Utility!=utility)throw new InvalidOperationException("Hunting discarded skill research.");checks++;
                string foreign=catalog.HeroIds.First(x=>!state.IsFactionHero(x));var oldParty=sim.Battle.Heroes.ToArray();var oldKits=sim.Battle.Kits[id];
                try{sim.SetParty(new[]{foreign});throw new InvalidOperationException("Foreign faction party accepted.");}catch(ArgumentException){}
                if(!oldParty.SequenceEqual(sim.Battle.Heroes)||!ReferenceEquals(oldKits,sim.Battle.Kits[id]))throw new InvalidOperationException("Rejected party replacement reset the expedition.");checks++;
                if((int)expected["max_hp"]>3000&&simulated<8)
                {for(int tick=0;tick<200;tick++)sim.Step(.05);if(sim.Kills==0)throw new InvalidOperationException("State-bound hunting did not settle any enemy death.");simulated++;checks++;}
                if(state.Snapshot().ToString()!=snapshot||saves!=0)throw new InvalidOperationException("Hunting credited its review ledger to a persistent wallet.");checks++;
            }
            var fresh=new JObject{{"selected_faction","aurelia"},{"deployed_hero_ids",new JArray("leonhardt","mira","elisia")},{"hero_progress",new JObject{{"leonhardt",new JObject{{"level",60},{"xp",0}}}}},{"wallet_gold",100000},{"unknown_world",new JObject{{"keep",true}}}};
            var live=new GameStateCommands(catalog,fresh,_=>{saves++;return true;});var hunt=new HuntingSimulation(1,9514,live);var actor=hunt.Battle.Heroes[0];var liveKit=hunt.Battle.Kits[actor.Id];
            actor.Hp=actor.MaxHp/3;double hpRatio=actor.HpRatio;actor.Shield=14;actor.Stun=.4;actor.Ultimate=37;actor.Windup=.18;actor.AttackRemaining=.7;
            liveKit.Cooldowns["a1"]=5;liveKit.PassiveCount=7;liveKit.PassiveRemaining=3;liveKit.Casts["a1"]=2;
            int oldAttack=actor.Attack;var position=actor.Position;var oldChain=hunt.Chain;
            if(!live.UpgradeResearch(actor.Id,"offense").Ok||!live.UpgradeResearch(actor.Id,"utility").Ok||!live.EnhanceGear("",actor.Id,"weapon").Ok)throw new InvalidOperationException("Live growth setup failed.");
            hunt.RefreshHeroGrowth();
            if(actor.Attack<=oldAttack||actor.Hp!=Math.Max(1,(int)Math.Round(actor.MaxHp*hpRatio,MidpointRounding.AwayFromZero))||liveKit.Utility!=1||actor.Position!=position||!ReferenceEquals(oldChain,hunt.Chain))throw new InvalidOperationException("Live growth did not refresh power in the existing expedition.");checks+=5;
            if(actor.Shield!=14||actor.Stun!=.4||actor.Ultimate!=37||actor.Windup!=.18||actor.AttackRemaining!=.7||liveKit.Cooldowns["a1"]!=5||liveKit.PassiveCount!=7||liveKit.PassiveRemaining!=3||liveKit.Casts["a1"]!=2)throw new InvalidOperationException("Live growth reset battle timing or passive progression.");checks+=9;
            actor.Hp=0;hunt.RefreshHeroGrowth();if(actor.Alive)throw new InvalidOperationException("Live growth revived a defeated party member.");checks++;
            if(live.Snapshot()["unknown_world"].ToString()!=fresh["unknown_world"].ToString()||saves!=3)throw new InvalidOperationException("Growth replayed a save or lost unknown world data.");checks+=2;
            return new JObject{{"passed",true},{"comparisons",checks},{"production_stat_bound_cases",cases.Count},{"ten_second_hunts",simulated},{"growth_commands",3},{"foreign_faction_replacement_is_atomic",true},{"review_ledger_does_not_credit_player_wallet",true},{"live_growth_retains_cooldowns_passives_hp_ratio_and_dead_state",true}};
        }
        static void Compare(JObject actual,JObject expected,string label,ref int comparisons)
        {
            foreach(var p in expected.Properties())
            {
                comparisons++;var value=actual[p.Name];bool number=p.Value.Type==JTokenType.Integer||p.Value.Type==JTokenType.Float;
                if(value==null||number&&(value.Type!=JTokenType.Integer&&value.Type!=JTokenType.Float||Math.Abs(value.Value<double>()-p.Value.Value<double>())>.00000001)||!number&&value.ToString()!=p.Value.ToString())throw new InvalidOperationException("Original combat stat differs: "+label+" "+p.Name+" = "+value+" expected "+p.Value);
            }
        }
    }
}
