using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using Newtonsoft.Json.Linq;
using UnityEngine;

namespace Eternal.UnityMigration.Editor
{
    public static class ReferenceFocusVerification
    {
        public static string Verify()
        {
            int checks=0;float clearance=float.MaxValue;var results=new JArray();
            void Check(bool ok,string label){checks++;if(!ok)throw new InvalidOperationException("Reference focus: "+label);}
            var battle=new CombatEncounter();for(int i=0;i<12;i++)battle.Enemies.Add(new Combatant{Serial=i,Hp=100,Position=new Vector2(i+1,0)});
            var selected=new HashSet<int>();HuntExpeditionPlan.Select(battle,Vector2.zero,selected);Check(selected.Count==5&&selected.Contains(0)&&!selected.Contains(11),"nearest engagement window");
            Check(Vector2.Distance(HuntExpeditionPlan.CohesiveGoal(new Vector2(25,25),Vector2.zero),Vector2.zero)<=8.001f,"bounded goal preference");
            foreach(string zone in new[]{"gray_meadow","forgotten_mine","moonrest_forest"})
            {
                var hunt=new HuntingSimulation(50){Zone=zone};hunt.Battle.Enemies.Clear();hunt.SpawnPack();
                for(int tick=0;tick<400;tick++)
                {
                    hunt.Step(.05);Check(!hunt.Defeated,"coordinated party survives fixture");Check(hunt.EngagementEnemyCount<=6,"shared front bounded");
                    var actors=hunt.Battle.Heroes.Concat(hunt.Battle.Enemies).Where(a=>a.Alive).ToArray();
                    foreach(var a in actors)Check(Vector2.Distance(a.Position,a.PreviousPosition)<=.111f,"automatic movement remains bounded");
                    for(int i=0;i<actors.Length;i++)for(int j=i+1;j<actors.Length;j++){var axes=hunt.BodyAxes(actors[i],actors[j]);var d=actors[i].Position-actors[j].Position;float n=new Vector2(d.x/axes.x,d.y/axes.y).magnitude;clearance=Mathf.Min(clearance,n);Check(n>=.999f,"body separation");}
                }
                Check(hunt.PacksCleared>0,"natural coordinated fixture progress");results.Add(new JObject{{"zone",zone},{"packs",hunt.PacksCleared},{"survivors",hunt.Battle.Heroes.Count(h=>h.Alive)}});
                var raid=new RaidSimulation(zone,50);Check(!raid.BreakSkillReady&&!raid.CastBreakSkill(),"no fabricated break outside warning");
                foreach(var h in raid.Battle.Heroes){h.Ultimate=100;foreach(string slot in new[]{"a1","a2"})raid.Battle.Kits[h.Id].Cooldowns[slot]=0;}
                raid.StartWarning((JObject)raid.Design["phases"][0]);Check(raid.BreakSkillReady,"existing stun available");
                double elapsed=raid.Elapsed;int before=raid.Interrupts;Check(raid.CastBreakSkill()&&(raid.Interrupts>before||raid.BreakGauge>0),"original control settles break");Check(raid.Elapsed==elapsed&&raid.DodgeRemaining==0,"action does not invent time or immunity");
                raid.StartWarning((JObject)raid.Design["phases"][0]);raid.ControlImmunity=6;Check(!raid.BreakSkillReady&&!raid.CastBreakSkill(),"control immunity gate");raid.ControlImmunity=0;raid.Paused=true;Check(!raid.CastBreakSkill(),"paused gate");
            }
            var vfx=SkillVfxVerification.Verify();var result=new JObject{{"passed",true},{"comparisons",checks},{"minimum_clearance",clearance},{"hunt_cases",results},{"vfx",vfx},{"note","Coordinated movement fixtures and original-skill stagger response. Seven shared geometric accents, existing painted atlas and 120 catalog profiles; not 120 bespoke assets, full four-game quality match or FPS proof."}};
            File.WriteAllText("../checks/unity-migration-2026-10-08/reference-focus-cp16.json",result.ToString());return result.ToString();
        }
    }
}
