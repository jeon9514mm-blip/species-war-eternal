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
                if(Resources.Load<Material>("Eternal/Materials/PaintedSkillShapes")==null)throw new InvalidOperationException("Painted skill shapes have not been imported.");
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
                    if(batch.ActiveEffects!=1||batch.Quads<=0||batch.PaintedChargeQuads!=1||batch.PaintedImpactQuads!=0||batch.PaintedFlightQuads!=0)throw new InvalidOperationException("Charge geometry missing or premature painted impact.");
                    batch.Advance(.1f,false);
                    if(batch.ActiveEffects!=0||batch.Quads!=0)throw new InvalidOperationException("Interrupted charge produced an impact.");
                    bool support=profile.Kind=="heal"||profile.Kind=="barrier"||profile.Kind=="guard";
                    if(support)batch.Observe(new BattleEvent(profile.Kind=="heal"?"heal":profile.Kind=="barrier"?"shield":"guard",hero,profile.Slot,hero),battle);
                    batch.Observe(new BattleEvent("cast",hero,profile.Slot,target),battle);batch.Advance(.03f,false);
                    if(batch.ActiveEffects!=1||batch.Quads<=0||batch.Quads>SkillVfxBatch.QuadsPerEffect||batch.PaintedImpactQuads!=1||batch.PaintedQuads>SkillVfxBatch.PaintedQuadsPerEffect)throw new InvalidOperationException("Settled VFX geometry exceeds budget or painted impact is missing.");
                    if(support&&(Mathf.Abs(batch.PaintedBounds.center.x-hero.Position.x)>.01f||batch.PaintedFlightQuads!=0))throw new InvalidOperationException("Support painted on its enemy aim instead of actual recipient.");
                    batch.Advance(.4f,false);
                    if(batch.ActiveEffects!=1||batch.PaintedImpactQuads!=0||batch.PaintedFlightQuads!=0||batch.PaintedTailQuads!=1)throw new InvalidOperationException("Tail should retain a restrained shape after its impact and flight expire.");
                    batch.Advance(2,false);if(batch.ActiveEffects!=0||batch.Quads!=0||batch.PaintedQuads!=0)throw new InvalidOperationException("VFX timeline leaked.");comparisons+=4;
                    comparisons+=2;
                }
                if(motifs.Count!=30||identities.Count!=30)throw new InvalidOperationException("Hero VFX identity collapsed.");comparisons+=2;
                var source=sim.Battle.Heroes.First(h=>!new[]{"heal","barrier","guard"}.Contains(batch.Profiles[h.Id+":ultimate"].Kind));var victim=sim.Battle.Enemies[0];int hp=victim.Hp;double time=sim.Elapsed;
                for(int i=0;i<200;i++)batch.Observe(new BattleEvent("cast",source,"ultimate",victim),sim.Battle);
                batch.Advance(.04f,false);
                var painted=owner.GetComponentsInChildren<MeshFilter>().First(f=>f.sharedMesh.name.StartsWith("Bounded painted",StringComparison.Ordinal)).sharedMesh;
                float normalAlpha=painted.colors.Max(c=>c.a);batch.Advance(0,true);float warningAlpha=painted.colors.Max(c=>c.a);
                if(normalAlpha<=0||warningAlpha>normalAlpha*.25f)throw new InvalidOperationException("Painted skills obscure authoritative raid warnings.");comparisons++;
                if(batch.ActiveEffects!=50||batch.Quads>50*96||batch.PaintedImpactQuads!=50||batch.PaintedQuads>50*SkillVfxBatch.PaintedQuadsPerEffect||victim.Hp!=hp||sim.Elapsed!=time||Time.timeScale!=1)
                    throw new InvalidOperationException("VFX pool overflow or simulation authority violation.");comparisons+=5;
                int peak=batch.Quads;batch.Advance(2,false);if(batch.ActiveEffects!=0)throw new InvalidOperationException("Saturated pool did not expire.");comparisons++;
                var healProfile=batch.Profiles.Values.First(p=>p.Kind=="heal"&&p.Slot=="a1");
                var healingBattle=new CombatEncounter();
                var healer=new Combatant{Id=healProfile.Hero,Serial=900,Position=new Vector2(-4,0),Hp=500,MaxHp=10000,Attack=100,Ultimate=100};
                var enemy=new Combatant{Id="fixture_enemy",Serial=902,Position=new Vector2(4,0),Hp=10000,MaxHp=10000};
                healingBattle.Heroes.Add(healer);healingBattle.Enemies.Add(enemy);healingBattle.Kits[healer.Id]=new HeroKitState(sim.Catalog,healer.Id,0,healer.Position);
                batch.Clear();int heals=0;healingBattle.OnEvent=e=>{if(e.Slot==healProfile.Slot){if(e.Kind=="heal")heals++;batch.Observe(e,healingBattle);}};
                if(!HeroKitExecution.Cast(healingBattle,healer,healProfile.Slot,enemy))throw new InvalidOperationException("Original support cast fixture did not execute.");
                batch.Advance(.03f,false);
                if(heals==0||healer.Hp<=500||batch.PaintedImpactQuads==0||batch.PaintedBounds.max.x>=0||enemy.Hp!=10000)throw new InvalidOperationException("Real support settlement did not keep healing art on its recipients.");comparisons+=5;
                echoes=new PaintedAfterImages(owner.transform);
                var atlas=OriginalCatalog.Atlas(source.Id);var pose=atlas.attack.frames[0];
                var snapshot=new PaintedPoseSnapshot(OriginalCatalog.Texture(source.Id),owner.transform,pose,1.9f/atlas.attack.native_height,1000);
                for(int i=0;i<250;i++)echoes.Capture(snapshot);echoes.Advance(.01f);
                if(echoes.ActiveCount!=50)throw new InvalidOperationException("Afterimage pool exceeded or lost its 50-slot capacity.");comparisons++;
                echoes.Advance(.4f);if(echoes.ActiveCount!=0)throw new InvalidOperationException("Afterimage pool leaked expired poses.");comparisons++;
                // Scene teardown may destroy child renderers before the review
                // owner. Repeated clear/dispose must remain safe in that order.
                foreach(var child in owner.GetComponentsInChildren<MeshRenderer>())if(child.name.StartsWith("Paint echo "))UnityEngine.Object.DestroyImmediate(child.gameObject);
                echoes.Clear();echoes.Dispose();echoes.Dispose();echoes.Advance(.1f);echoes.Capture(snapshot);comparisons++;
                var oldMesh=OriginalReliefMesh.Load(source.Id).Body;oldMesh.Clear();
                var restored=OriginalReliefMesh.Load(source.Id).Body;
                if(restored==null||restored.vertexCount==0||restored.triangles.Length/3!=6000)throw new InvalidOperationException("Empty cached original body was reused.");comparisons++;
                if(errors.Count>0)throw new InvalidOperationException("VFX fixture logged renderer errors: "+string.Join(" / ",errors));comparisons++;
                var result=new JObject{{"passed",true},{"comparisons",comparisons},{"skill_profiles",120},{"hero_motifs",30},{"pool_capacity",50},{"painted_shape_cells",8},{"painted_max_quads",50*SkillVfxBatch.PaintedQuadsPerEffect},{"painted_charge_flight_impact_tail",true},{"actual_support_recipient_verified",true},{"raid_warning_opacity_verified",true},{"afterimage_pool_capacity",50},{"afterimage_lifetime",.4},{"empty_body_cache_recovery",true},{"saturated_quad_count",peak},{"max_quads_per_effect",96},{"renderer_errors_during_fixture",errors.Count},{"note","Bounded CPU mesh timelines plus eight shared painted shapes; not GPU particles, 120 bespoke painted textures or proof that all 120 skills have been visually reviewed. Actual original healing execution verifies recipient anchoring."}};
                File.WriteAllText("../checks/unity-migration-2026-10-08/native-skill-vfx.json",result.ToString());return result;
            }
            finally{Application.logMessageReceived-=Log;batch?.Dispose();echoes?.Dispose();UnityEngine.Object.DestroyImmediate(owner);}
        }
    }
}
