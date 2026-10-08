using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using Newtonsoft.Json.Linq;
using UnityEngine;

namespace Eternal.UnityMigration.Editor
{
    public static class SkillVfxVerification
    {
        public static JObject Verify()
        {
            if(Application.isPlaying)throw new InvalidOperationException("VFX fixture runs outside Play mode.");
            var owner=new GameObject("Isolated VFX fixture");SkillVfxBatch batch=null;PaintedAfterImages echoes=null;var errors=new List<string>();
            void Log(string condition,string stack,LogType type){if(type==LogType.Error||type==LogType.Exception||type==LogType.Assert)errors.Add(condition);}
            Application.logMessageReceived+=Log;
            try
            {
                var catalog=JObject.Parse(OriginalCatalog.Required("legacy-catalogs").text);
                batch=new SkillVfxBatch(owner.transform,Resources.Load<Material>("Eternal/Materials/Particles"),(JArray)catalog["skill_vfx"]);
                var motifs=new HashSet<string>();var identities=new HashSet<string>();var sim=new HuntingSimulation(50);int comparisons=0;
                if(batch.Profiles.Count!=120)throw new InvalidOperationException("Missing original VFX profiles.");
                foreach(var profile in batch.Profiles.Values)
                {
                    motifs.Add(profile.Motif);identities.Add(profile.Hero+":"+profile.Glyph);
                    if(!sim.Catalog.HeroIds.Contains(profile.Hero))throw new InvalidOperationException("Unknown VFX hero: "+profile.Hero);
                    if(profile.Lifetime<.45f||profile.Lifetime>1.4f||profile.Family<0||profile.Family>6)throw new InvalidOperationException("Unbounded VFX profile.");comparisons+=3;
                    var hero=new Combatant{Id=profile.Hero,Serial=400,Position=new Vector2(-1,0),Hp=100};
                    var target=new Combatant{Id="target",Serial=401,Position=new Vector2(1,0),Hp=100};
                    var battle=new CombatEncounter();battle.Heroes.Add(hero);battle.Enemies.Add(target);
                    batch.Clear();
                    if(!batch.Observe(new BattleEvent("windup",hero,profile.Slot,target),battle))throw new InvalidOperationException("Missing charge timeline.");
                    batch.Advance(.1f,false);
                    if(batch.ActiveEffects!=1||batch.Quads<=0)throw new InvalidOperationException("Charge geometry missing.");
                    batch.Advance(.1f,false);
                    if(batch.ActiveEffects!=0||batch.Quads!=0)throw new InvalidOperationException("Interrupted charge produced an impact.");
                    batch.Observe(new BattleEvent("cast",hero,profile.Slot,target),battle);batch.Advance(.03f,false);
                    if(batch.ActiveEffects!=1||batch.Quads<=0||batch.Quads>SkillVfxBatch.QuadsPerEffect)throw new InvalidOperationException("Settled VFX geometry exceeds budget.");
                    batch.Advance(2,false);if(batch.ActiveEffects!=0||batch.Quads!=0)throw new InvalidOperationException("VFX timeline leaked.");comparisons+=4;
                }
                if(motifs.Count!=30||identities.Count!=30)throw new InvalidOperationException("Hero VFX identity collapsed.");comparisons+=2;
                var source=sim.Battle.Heroes[0];var victim=sim.Battle.Enemies[0];int hp=victim.Hp;double time=sim.Elapsed;
                for(int i=0;i<200;i++)batch.Observe(new BattleEvent("cast",source,"ultimate",victim),sim.Battle);
                batch.Advance(.04f,true);
                if(batch.ActiveEffects!=50||batch.Quads>50*96||victim.Hp!=hp||sim.Elapsed!=time||Time.timeScale!=1)
                    throw new InvalidOperationException("VFX pool overflow or simulation authority violation.");comparisons+=5;
                int peak=batch.Quads;batch.Advance(2,false);if(batch.ActiveEffects!=0)throw new InvalidOperationException("Saturated pool did not expire.");comparisons++;
                echoes=new PaintedAfterImages(owner.transform);
                var atlas=OriginalCatalog.Atlas(source.Id);var pose=atlas.attack.frames[0];
                var snapshot=new PaintedPoseSnapshot(Resources.Load<Texture2D>("Eternal/Actors/"+source.Id+"/poses"),owner.transform,pose,1.9f/atlas.attack.native_height,1000);
                for(int i=0;i<250;i++)echoes.Capture(snapshot);echoes.Advance(.01f);
                if(echoes.ActiveCount!=50)throw new InvalidOperationException("Afterimage pool exceeded or lost its 50-slot capacity.");comparisons++;
                echoes.Advance(.4f);if(echoes.ActiveCount!=0)throw new InvalidOperationException("Afterimage pool leaked expired poses.");comparisons++;
                var oldMesh=OriginalReliefMesh.Load(source.Id).Body;oldMesh.Clear();
                var restored=OriginalReliefMesh.Load(source.Id).Body;
                if(restored==null||restored.vertexCount==0||restored.triangles.Length/3!=6000)throw new InvalidOperationException("Empty cached original body was reused.");comparisons++;
                if(errors.Count>0)throw new InvalidOperationException("VFX fixture logged renderer errors: "+string.Join(" / ",errors));comparisons++;
                var result=new JObject{{"passed",true},{"comparisons",comparisons},{"skill_profiles",120},{"hero_motifs",30},{"pool_capacity",50},{"afterimage_pool_capacity",50},{"afterimage_lifetime",.4},{"empty_body_cache_recovery",true},{"saturated_quad_count",peak},{"max_quads_per_effect",96},{"renderer_errors_during_fixture",errors.Count},{"note","Bounded CPU mesh timelines; not GPU particles or proof that all 120 skills have been visually reviewed."}};
                File.WriteAllText("../checks/unity-migration-2026-10-08/native-skill-vfx.json",result.ToString());return result;
            }
            finally{Application.logMessageReceived-=Log;batch?.Dispose();echoes?.Dispose();UnityEngine.Object.DestroyImmediate(owner);}
        }
    }
}
