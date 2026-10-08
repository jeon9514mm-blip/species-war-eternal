using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Linq;
using Newtonsoft.Json.Linq;
using UnityEngine;

namespace Eternal.UnityMigration.Editor
{
    public static class HuntingSimulationVerification
    {
        public static string Verify()
        {
            if(Application.isPlaying)return NativeRendererVerification.Verify();
            var report=new JArray();var timer=Stopwatch.StartNew();int comparisons=0;double worstMove=0,minClearance=double.MaxValue;
            foreach(string zone in new[]{"gray_meadow","forgotten_mine","moonrest_forest"})
            {
                var sim=new HuntingSimulation(50,9514);sim.Zone=zone;sim.Battle.Enemies.Clear();sim.SpawnPack();int damage=0,casts=0;
                sim.OnEvent=e=>{if(e.Kind=="damage")damage+=e.Amount;if(e.Kind=="cast")casts++;};
                for(int tick=0;tick<2400&&!sim.Defeated;tick++)
                {
                    sim.Step(.05);var actors=sim.Battle.Heroes.Concat(sim.Battle.Enemies).Where(a=>a.Alive).ToArray();
                    foreach(var actor in actors)
                    {
                        double moved=Vector2.Distance(actor.Position,actor.PreviousPosition);worstMove=Math.Max(worstMove,moved);comparisons++;
                        if(moved>.111)throw new InvalidOperationException("Unbounded movement correction: "+actor.Id+" "+moved);
                    }
                    if(tick%5!=0)continue;
                    for(int a=0;a<actors.Length;a++)for(int b=a+1;b<actors.Length;b++)
                    {
                        var axes=sim.BodyAxes(actors[a],actors[b]);var delta=actors[a].Position-actors[b].Position;
                        double distance=new Vector2(delta.x/axes.x,delta.y/axes.y).magnitude;minClearance=Math.Min(minClearance,distance);comparisons++;
                        if(distance<.999)throw new InvalidOperationException("Body clearance violation: "+actors[a].Id+" / "+actors[b].Id+" "+distance);
                    }
                }
                if(sim.PacksCleared<2||damage<=0||casts<=0)throw new InvalidOperationException("Hunting stalled in "+zone+" packs="+sim.PacksCleared+" casts="+casts);
                int ticks=sim.Ticks,gold=sim.Gold;sim.Paused=true;sim.Step(.05);comparisons+=2;
                if(sim.Ticks!=ticks||sim.Gold!=gold)throw new InvalidOperationException("Paused simulation changed state.");
                report.Add(new JObject{{"zone",zone},{"simulated_seconds",sim.Elapsed},{"packs_cleared",sim.PacksCleared},{"kills",sim.Kills},{"casts",casts},{"damage",damage}});
            }
            var chainReport=VerifyChain(ref comparisons);
            RaidSimulationVerification.Verify();
            var vfxReport=SkillVfxVerification.Verify();
            var result=new JObject{{"passed",true},{"comparisons",comparisons},{"maximum_tick_movement",worstMove},{"minimum_normalized_body_clearance",minClearance},{"verification_elapsed_ms",timer.ElapsedMilliseconds},{"scenarios",report},{"skill_chain",chainReport},{"note","Isolated domain verification; not a renderer FPS benchmark or full economy parity."}};
            result["skill_vfx"]=vfxReport;
            Directory.CreateDirectory("../checks/unity-migration-2026-10-08");File.WriteAllText("../checks/unity-migration-2026-10-08/native-hunt-simulation.json",result.ToString());return result.ToString();
        }
        static JObject VerifyChain(ref int comparisons)
        {
            var sim=new HuntingSimulation(50,9514);sim.Chain.Enabled=true;var chain=sim.Chain;
            var expected=chain.Current;int matched=0;
            sim.OnEvent=e=>
            {
                if(e.Kind!="cast")return;
                var cast=new ChainSkill(e.Source,e.Slot);
                if(expected.HasValue&&expected.Value.Equals(cast)){matched++;expected=chain.Current;}
            };
            for(int tick=0;tick<2400&&!sim.Defeated;tick++)sim.Step(.05);
            comparisons+=3;
            if(chain.CompletedCycles<1||sim.PacksCleared<2||matched!=chain.ConfirmedCasts)
                throw new InvalidOperationException("Skill chain stalled or advanced without confirmed casts: cycles="+chain.CompletedCycles+" matched="+matched+" confirmed="+chain.ConfirmedCasts);
            var snapshot=chain.Entries.ToArray();
            if(chain.Set(0,new ChainSkill(snapshot[0].Hero,"passive"))||chain.Set(-1,snapshot[0])||chain.Move(0,-1))throw new InvalidOperationException("Invalid chain edit accepted.");
            if(!snapshot.SequenceEqual(chain.Entries))throw new InvalidOperationException("Rejected chain edit changed order.");comparisons+=4;
            if(!chain.Move(0,1)||!chain.Entries[1].Equals(snapshot[0]))throw new InvalidOperationException("Chain reorder failed.");
            if(!chain.Set(0,chain.Entries[1])||chain.Entries.Distinct().Count()!=chain.Entries.Count)throw new InvalidOperationException("Chain replacement duplicated skill.");comparisons+=3;
            var triage=new HuntingSimulation(50);triage.Chain.Enabled=true;
            foreach(var h in triage.Battle.Heroes)h.Hp=Math.Max(1,h.MaxHp/5);
            var healer=triage.Battle.Heroes.FirstOrDefault(h=>triage.Battle.Kits[h.Id].Profiles.Any(p=>(string)p.Value["kind"]=="heal"&&p.Key!="passive"));
            if(healer==null)throw new InvalidOperationException("Expected an original party healer.");
            foreach(string slot in new[]{"a1","a2"})triage.Battle.Kits[healer.Id].Cooldowns[slot]=0;
            healer.Ultimate=100;string preferred=HeroKitExecution.PreferredSlot(triage.Battle,healer);
            if((string)triage.Battle.Kits[healer.Id].Profiles[preferred]["kind"]!="heal"||triage.Chain.Choose(healer,preferred)!=preferred)throw new InvalidOperationException("Offensive chain blocked emergency healing.");comparisons++;
            var stopped=new HuntingSimulation(50);stopped.Chain.Enabled=true;
            var first=stopped.Chain.Current.Value;var owner=stopped.Battle.Heroes.First(h=>h.Id==first.Hero);
            stopped.Battle.Kits[owner.Id].Cooldowns[first.Slot]=100;double cooldown=stopped.Battle.Kits[owner.Id].Cooldowns[first.Slot],energy=owner.Ultimate;int cursor=stopped.Chain.Cursor;
            if(HeroKitExecution.Cast(stopped.Battle,owner,first.Slot,stopped.Battle.Enemies[0]))throw new InvalidOperationException("Unavailable chain spell cast.");
            if(stopped.Chain.Cursor!=cursor||owner.Ultimate!=energy||stopped.Battle.Kits[owner.Id].Cooldowns[first.Slot]!=cooldown)throw new InvalidOperationException("Failed cast consumed chain state.");comparisons+=4;
            owner.Hp=0;stopped.Chain.Choose(stopped.Battle.Heroes.First(h=>h.Alive),"basic");
            if(stopped.Chain.Current.Value.Hero==owner.Id||stopped.Chain.ConfirmedCasts!=0)throw new InvalidOperationException("Dead chain owner froze or credited sequence.");comparisons++;
            return new JObject{{"enabled_simulated_seconds",sim.Elapsed},{"cycles",chain.CompletedCycles},{"confirmed_casts",chain.ConfirmedCasts},{"packs_cleared",sim.PacksCleared},{"reorder_and_replacement",true},{"triage_bypass",true},{"failed_cast_preserves_resources",true},{"dead_owner_skip",true}};
        }
    }
}
