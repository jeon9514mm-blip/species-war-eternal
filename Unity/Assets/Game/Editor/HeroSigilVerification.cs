using System;
using System.IO;
using System.Linq;
using Newtonsoft.Json.Linq;
using UnityEngine;

namespace Eternal.UnityMigration.Editor
{
    public static class HeroSigilVerification
    {
        public static string Verify()
        {
            int checks=0;void Check(bool ok,string label){checks++;if(!ok)throw new InvalidOperationException("Hero sigil: "+label);}
            var owner=new GameObject("Isolated CP18 sigil fixture");SkillVfxBatch batch=null;
            try
            {
                var data=JObject.Parse(OriginalCatalog.Required("legacy-catalogs").text);
                batch=new SkillVfxBatch(owner.transform,Resources.Load<Material>("Eternal/Materials/Particles"),(JArray)data["skill_vfx"]);
                var ids=PaintedHeroSigils.Heroes.SelectMany(x=>x).ToArray();var catalog=new OriginalCombatCatalog(OriginalCatalog.Required("hero-catalog").text);
                Check(ids.Length==30&&ids.Distinct().Count()==30&&ids.All(catalog.HeroIds.Contains),"all thirty canonical IDs mapped once");
                for(int bank=0;bank<2;bank++)for(int cell=0;cell<15;cell++)
                {
                    Check(PaintedHeroSigils.TryIcon(PaintedHeroSigils.Heroes[bank][cell],out var texture,out var uv)&&texture!=null,"icon texture available");
                    Check(uv.xMin>=0&&uv.yMin>=0&&uv.xMax<1&&uv.yMax<1&&uv==PaintedHeroSigils.CellUV(cell),"UV gutter and row orientation");
                }
                foreach(var profile in batch.Profiles.Values)
                {
                    var battle=new CombatEncounter();var hero=new Combatant{Id=profile.Hero,Serial=1,Hp=100,Position=Vector2.left};var target=new Combatant{Id="fixture",Serial=2,Hp=100,Position=Vector2.right};battle.Heroes.Add(hero);battle.Enemies.Add(target);
                    batch.Clear();bool support=profile.Kind=="heal"||profile.Kind=="barrier"||profile.Kind=="guard";
                    batch.Observe(new BattleEvent(support?(profile.Kind=="barrier"?"shield":profile.Kind):"cast",hero,profile.Slot,support?hero:target),battle);
                    batch.Advance(SkillVfxBatch.FlightDuration(profile,2,support)+.02f,false);
                    Check(batch.HeroSigilQuads==1&&batch.HeroSigilImpactQuads==1,"painted impact for "+profile.Signature);
                    batch.Advance(2,false);Check(batch.HeroSigilQuads==0,"sigil lifetime drains");
                }
                var sim=new HuntingSimulation(50);var source=sim.Battle.Heroes.First(h=>h.Id=="mira");var enemy=sim.Battle.Enemies[0];source.Position=Vector2.zero;enemy.Position=Vector2.right*3;enemy.Hp=enemy.MaxHp=100000;
                sim.Battle.Kits[source.Id].Cooldowns["a1"]=0;enemy.Position=Vector2.right;
                var timeline=new CombatHitFeedbackTimeline(batch.Profiles);int presented=0,settled=0;sim.Battle.OnEvent=e=>{if(e.Kind=="damage"||e.Kind=="critical"){settled++;timeline.Enqueue(e,sim.Battle,_=>presented++);}};
                int before=enemy.Hp;double clock=sim.Elapsed;HeroKitExecution.Cast(sim.Battle,source,"a1",enemy);
                Check(enemy.Hp<before&&settled>0&&presented==0&&timeline.Count>0,"real original skill settles before visual flight completes");int hp=enemy.Hp;
                timeline.Advance(.01f,_=>presented++);Check(presented==0&&enemy.Hp==hp&&sim.Elapsed==clock,"observer does not advance damage or clock");
                timeline.Advance(1,_=>presented++);Check(presented==settled&&timeline.Count==0,"confirmed hits presented exactly once");timeline.Advance(1,_=>presented++);Check(presented==settled,"no duplicate hit");
                var sample=new BattleEvent("damage",source,"a1",enemy,10);
                for(int i=0;i<200;i++)timeline.Enqueue(sample,sim.Battle,_=>presented++);
                Check(timeline.Count==128&&timeline.Dropped==72,"pending visual feedback bounded");timeline.Clear();timeline.Advance(1,_=>presented++);Check(timeline.Count==0&&presented==settled,"encounter reset cancels old presentation");
                foreach(string id in ids)
                {
                    var deep=HeroDeepPresentation.For(id);var surface=OriginalReliefMesh.Load(id);var mesh=deep.SelectHair(surface.Hair);
                    Check(mesh.triangles.Length/6==deep.HairCards,"actual authored hair triangle count "+id);
                    Check(deep.CapePoints==3||deep.CapePoints==5,"authored cape control count "+id);
                    if(mesh!=surface.Hair)UnityEngine.Object.DestroyImmediate(mesh);
                }
                foreach(int points in new[]{3,5})
                {
                    var cape=new CapeChainMotion();cape.Configure(points);
                    for(int frame=0;frame<600;frame++){cape.Advance(1/60f,frame/60f,frame%120<60?0:1,.3f);Check(cape.Sample(0)==Vector2.zero&&cape.Sample(1).magnitude<=2.601f,"bounded pinned secondary motion");}
                }
                var vfx=SkillVfxVerification.Verify();
                var report=new JObject{{"passed",true},{"comparisons",checks},{"original_vfx",vfx},{"heroes",30},{"slot_profiles",120},{"note","Two unchanged painted atlases, one identity motif per hero. All 120 original profiles exercise bounded painted timelines; not 120 independently authored bitmaps or mobile/FPS acceptance."}};
                File.WriteAllText("../checks/unity-migration-2026-10-08/hero-sigils-cp18.json",report.ToString());return report.ToString();
            }
            finally{batch?.Dispose();UnityEngine.Object.DestroyImmediate(owner);}
        }
    }
}
