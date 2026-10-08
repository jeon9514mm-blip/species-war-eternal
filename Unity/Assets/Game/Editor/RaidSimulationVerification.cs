using System;
using System.IO;
using System.Linq;
using Newtonsoft.Json.Linq;
using UnityEditor;
using UnityEngine;

namespace Eternal.UnityMigration.Editor
{
    public static class RaidSimulationVerification
    {
        public static string Verify()
        {
            var fixture=JObject.Parse(AssetDatabase.LoadAssetAtPath<TextAsset>("Assets/Game/Editor/Fixtures/raid-rule-fixtures.json").text);int comparisons=0;
            void Equal(string name,double actual,double expected)
            {comparisons++;if(Math.Abs(actual-expected)>.0001)throw new InvalidOperationException("Raid original parity: "+name+" actual="+actual+" original="+expected);}
            void State(RaidSimulation sim,JObject expected,string context)
            {
                Equal(context+" HP",sim.Boss.Hp,(double)expected["hp"]);Equal(context+" guard",sim.GuardHp,(double)expected["guard"]);Equal(context+" guard breaks",sim.GuardBreaks,(double)expected["guard_breaks"]);
                Equal(context+" adds",sim.AddHp,(double)expected["adds"]);Equal(context+" add count",sim.AddCount,(double)expected["add_count"]);Equal(context+" add waves",sim.AddWaves,(double)expected["add_waves"]);
                Equal(context+" DPS damage",sim.DpsDamage,(double)expected["dps_damage"]);Equal(context+" DPS passed",sim.DpsPassed,(double)expected["dps_passed"]);Equal(context+" DPS failed",sim.DpsFailed,(double)expected["dps_failed"]);
                Equal(context+" vulnerability",sim.Boss.Vulnerable,(double)expected["vulnerable"]);Equal(context+" total damage",sim.DamageDealt,(double)expected["damage"]);Equal(context+" enrage",sim.Enraged?1:0,(bool)expected["enraged"]?1:0);
            }
            foreach(JObject c in fixture["settlements"])
            {
                var sim=new RaidSimulation((string)c["zone"],100);int phase=(int)c["phase"];sim.Boss.Hp=(int)(sim.Boss.MaxHp*new[]{.95,.59,.29}[phase-1]);sim.AdvancePhase();sim.Boss.Vulnerable=(bool)c["vulnerable"]?1:0;sim.Battle.CriticalChance=(bool)c["critical"]?1:0;
                int emitted=0;sim.OnEvent=e=>{if(e.Kind=="damage"||e.Kind=="critical")emitted+=e.Amount;};
                Equal("first settlement",sim.Battle.DamageEnemy(sim.Battle.Heroes[0],sim.Boss,(int)c["raw"],"a1"),(double)c["first"]);
                Equal("second settlement",sim.Battle.DamageEnemy(sim.Battle.Heroes[0],sim.Boss,101,"a2"),(double)c["second"]);
                Equal("observer actual settled damage",emitted,(double)c["first"]+(double)c["second"]);State(sim,(JObject)c["state"],(string)c["zone"]+"/"+phase);
            }
            foreach(JObject c in fixture["controls"])
            {
                var sim=new RaidSimulation();sim.Boss.Hp=(bool)c["low_hp"]?sim.Boss.MaxHp/10:sim.Boss.MaxHp;
                if((bool)c["warning"])sim.StartWarning(new JObject{{"kind","aoe"},{"telegraph",1.2},{"name","fixture"}});sim.ControlImmunity=(bool)c["immune"]?6:0;
                Equal("control window",sim.ControlWindow?1:0,(bool)c["window"]?1:0);Equal("accepted control",sim.ApplyControl((double)c["duration"])?1:0,(bool)c["accepted"]?1:0);
                Equal("control stun",sim.Boss.Stun,(double)c["stun"]);Equal("control vulnerability",sim.Boss.Vulnerable,(double)c["vulnerable"]);Equal("control immunity",sim.ControlImmunity,(double)c["immunity"]);Equal("break gauge",sim.BreakGauge,(double)c["gauge"]);Equal("interrupt count",sim.Interrupts,(double)c["interrupts"]);Equal("warning cancellation",sim.Warning!=null?1:0,(bool)c["pending"]?1:0);
            }
            foreach(JObject c in fixture["expiries"])
            {
                var sim=new RaidSimulation("moonrest_forest",100);int phase=(int)c["phase"];sim.Boss.Hp=(int)(sim.Boss.MaxHp*(phase==2?.59:.29));sim.AdvancePhase();sim.Boss.Attack=0;
                foreach(var h in sim.Battle.Heroes)h.AttackRemaining=1000;
                for(int tick=0;tick<210;tick++)sim.Step(.05);
                State(sim,(JObject)c["state"],"DPS expiry "+phase);Equal("expired DPS timer",sim.DpsRemaining,0);
            }
            Vector2 Convert(JToken p)=>new(((float)p[0]-519)/25,((float)p[1]-383)/25);
            foreach(JObject c in fixture["footprints"])
            {
                var shape=RaidFootprint.Create((string)c["kind"],new Vector2(4.64f,.56f),new[]{new Vector2(-7.16f,-1.8f),new Vector2(.52f,1.72f)},new JObject());
                foreach(JObject point in c["points"])
                {
                    var p=Convert(point["point"]);Equal((string)c["kind"]+" footprint",shape.Contains(p)?1:0,(bool)point["contains"]?1:0);
                    var escape=shape.Escape(p);var expected=Convert(point["escape"]);
                    // Equally short radial samples can exchange order after a
                    // pixel->world float conversion. Compare safety and distance.
                    Equal((string)c["kind"]+" escape safety",shape.Contains(escape)?1:0,shape.Contains(expected)?1:0);
                    Equal((string)c["kind"]+" escape length",Vector2.Distance(escape,p),Vector2.Distance(expected,p));
                }
            }
            var runs=new JArray();float worst=0,minClearance=float.MaxValue;
            foreach(string zone in new[]{"gray_meadow","forgotten_mine","moonrest_forest"})
            {
                var sim=new RaidSimulation(zone,100);for(int tick=0;tick<4800&&sim.Running;tick++)
                {
                    sim.Step(.05);var alive=sim.Battle.Heroes.Concat(sim.Battle.Enemies).Where(a=>a.Alive).ToArray();
                    foreach(var a in alive){float moved=Vector2.Distance(a.Position,a.PreviousPosition);worst=Mathf.Max(worst,moved);comparisons++;if(moved>.221f)throw new InvalidOperationException("Raid position snapped: "+a.Id+" "+moved);}
                    if(tick%4!=0)continue;for(int i=0;i<alive.Length;i++)for(int j=i+1;j<alive.Length;j++)
                    {var axes=RaidSimulation.BodyAxes(alive[i],alive[j]);var d=alive[i].Position-alive[j].Position;float normalized=new Vector2(d.x/axes.x,d.y/axes.y).magnitude;minClearance=Mathf.Min(minClearance,normalized);comparisons++;if(normalized<.999f)throw new InvalidOperationException("Raid body overlap: "+alive[i].Id+" / "+alive[j].Id+" "+normalized);}
                }
                if(sim.Ticks<20||sim.DamageDealt<=0||sim.Patterns+sim.Interrupts==0)throw new InvalidOperationException("Raid did not exercise combat/patterns: "+zone);
                int ticks=sim.Ticks,hp=sim.Boss.Hp;sim.Paused=true;sim.Step(.05);Equal("pause ticks",sim.Ticks,ticks);Equal("pause HP",sim.Boss.Hp,hp);
                runs.Add(new JObject{{"zone",zone},{"outcome",sim.Outcome},{"seconds",sim.Elapsed},{"phase",sim.Phase},{"damage",sim.DamageDealt},{"patterns",sim.Patterns},{"interrupts",sim.Interrupts},{"survivors",sim.Battle.Heroes.Count(h=>h.Alive)}});
            }
            var dodge=new RaidSimulation();dodge.StartWarning(new JObject{{"kind","aoe"},{"telegraph",1.2},{"name","fixture"}});
            var before=dodge.Battle.Heroes.Select(h=>h.Position).ToArray();if(!dodge.Dodge()||dodge.Dodge())throw new InvalidOperationException("Dodge cooldown not enforced.");
            for(int i=0;i<before.Length;i++){Equal("dodge no instant X",dodge.Battle.Heroes[i].Position.x,before[i].x);Equal("dodge no instant Y",dodge.Battle.Heroes[i].Position.y,before[i].y);}
            var atlas=OriginalCatalog.Atlas("leonhardt");for(int frame=0;frame<200;frame++)
            {int index=PaintedActor.PoseIndex(atlas,1,frame*.11f,0,0,frame*.1f)-atlas.attack.frames.Length;comparisons++;if(index<2||index>5)throw new InvalidOperationException("Walking selected hit/death pose.");}
            int heroMeshes=0;foreach(var entry in OriginalCatalog.Actors.entries)
            {
                var mesh=OriginalReliefMesh.Load(entry.id);if(mesh==null)throw new InvalidOperationException("Original relief could not load: "+entry.id);
                comparisons++;if(entry.hero){Equal("hero body triangles",mesh.Body.triangles.Length/3,6000);Equal("hero hair cards",mesh.Hair.triangles.Length/6,600);heroMeshes++;}
                if(entry.hero&&mesh.BodyLod==null)throw new InvalidOperationException("Hero relief LOD missing: "+entry.id);
            }
            var cape=new CapeChainMotion();for(int i=0;i<600;i++){cape.Advance(1/60f,i/60f,.8f,.4f);foreach(var point in cape.Points){comparisons++;if(!float.IsFinite(point.x)||!float.IsFinite(point.y)||point.magnitude>2.6001f)throw new InvalidOperationException("Cape chain diverged.");}Equal("cape pinned root",cape.Points[0].magnitude,0);}
            var result=new JObject{{"passed",true},{"comparisons",comparisons},{"original_damage_cases",fixture["settlements"].Count()},{"original_control_cases",fixture["controls"].Count()},{"original_geometry_cases",fixture["footprints"].Sum(c=>c["points"].Count())},{"maximum_tick_movement",worst},{"minimum_normalized_clearance",minClearance},{"hero_relief_meshes",heroMeshes},{"hair_cards_per_hero",600},{"analytic_cape_controls",5},{"runs",runs},{"note","Production raid math/geometry oracle and isolated domain runs; mesh decoding and bounded analytic cape checks. Not full player-economy parity, visual acceptance, native SSS or an FPS measurement."}};
            Directory.CreateDirectory("../checks/unity-migration-2026-10-08");File.WriteAllText("../checks/unity-migration-2026-10-08/native-raid-simulation.json",result.ToString());return result.ToString();
        }
    }
}
