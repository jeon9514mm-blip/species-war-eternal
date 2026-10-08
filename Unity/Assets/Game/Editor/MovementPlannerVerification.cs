using System;
using System.IO;
using System.Collections.Generic;
using System.Linq;
using Newtonsoft.Json.Linq;
using UnityEngine;

namespace Eternal.UnityMigration.Editor
{
    public static class MovementPlannerVerification
    {
        public static JObject Verify()
        {
            var fixture=JObject.Parse(File.ReadAllText("Assets/Game/Editor/Fixtures/movement-standoff-fixtures.json"));int comparisons=0;
            foreach(JObject row in fixture["cases"])
            {
                var h=new Combatant{Role=(string)row["role"],Style=(string)row["style"],Range=(int)row["range"]};
                comparisons++;if(Math.Abs(HuntPositionPlanner.PreferredStandoff(h,(bool)row["melee"])-(double)row["expected"])>.00001)throw new InvalidOperationException("Original role standoff changed: "+row);
            }
            var parties=new JArray();var catalog=new OriginalCombatCatalog(OriginalCatalog.Required("hero-catalog").text);
            foreach(JObject row in fixture["layout"])
            {int slot=(int)row["slot"];comparisons+=2;if(LegacyHeroLayout.Row(slot)!=(string)row["row"]||LegacyHeroLayout.Range(catalog.Hero((string)row["hero"]),slot)!=(int)row["range"])throw new InvalidOperationException("Original formation row/range changed: "+row);}
            var groups=new List<string[]>();
            foreach(string faction in catalog.HeroIds.Select(id=>(string)catalog.Hero(id)["faction"]).Distinct())
            {var ids=catalog.HeroIds.Where(id=>(string)catalog.Hero(id)["faction"]==faction).ToArray();groups.Add(ids.Take(10).ToArray());groups.Add(ids.Skip(5).Take(10).ToArray());}
            for(int group=0;group<groups.Count;group++)
            {
                var sim=new HuntingSimulation(50,9514+group);sim.SetParty(groups[group]);
                sim.Battle.Enemies.Clear();sim.SpawnPack();int casts=0;sim.OnEvent=e=>{if(e.Kind=="cast")casts++;};
                for(int i=0;i<1200&&!sim.Defeated;i++)
                {
                    sim.Step(.05);
                    foreach(var h in sim.Battle.Heroes.Where(a=>a.Alive))
                    {
                        comparisons++;if(Vector2.Distance(h.PreviousPosition,h.Position)>.111f)throw new InvalidOperationException("Party movement teleported: "+h.Id);
                        foreach(var other in sim.Battle.Heroes.Where(a=>a.Alive&&a.Serial>h.Serial))
                        {var axes=sim.BodyAxes(h,other);var d=h.Position-other.Position;comparisons++;if(new Vector2(d.x/axes.x,d.y/axes.y).magnitude<.999f)throw new InvalidOperationException("Party bodies overlapped: "+h.Id+" / "+other.Id);}
                    }
                }
                if(sim.PacksCleared<2||casts==0)throw new InvalidOperationException("Ten-hero original party stalled: "+group+" packs="+sim.PacksCleared);
                parties.Add(new JObject{{"group",group},{"faction",(string)catalog.Hero(groups[group][0])["faction"]},{"hero_ids",new JArray(sim.Battle.Heroes.Select(h=>h.Id))},{"packs_cleared",sim.PacksCleared},{"casts",casts}});
            }
            var result=new JObject{{"passed",true},{"comparisons",comparisons},{"production_standoff_cases",((JArray)fixture["cases"]).Count},{"all_30_hero_party_scenarios",parties},{"note","Role distances match original source. The bounded angular/reservation planner is an adaptation; body clearance is not proof of complete painted silhouette separation."}};
            File.WriteAllText("../checks/unity-migration-2026-10-08/movement-planner.json",result.ToString());return result;
        }
    }
}
