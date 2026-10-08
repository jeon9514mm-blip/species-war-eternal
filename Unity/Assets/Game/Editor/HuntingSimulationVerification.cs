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
            var result=new JObject{{"passed",true},{"comparisons",comparisons},{"maximum_tick_movement",worstMove},{"minimum_normalized_body_clearance",minClearance},{"verification_elapsed_ms",timer.ElapsedMilliseconds},{"scenarios",report},{"note","Isolated domain verification; not a renderer FPS benchmark or full economy parity."}};
            Directory.CreateDirectory("../checks/unity-migration-2026-10-08");File.WriteAllText("../checks/unity-migration-2026-10-08/native-hunt-simulation.json",result.ToString());return result.ToString();
        }
    }
}
