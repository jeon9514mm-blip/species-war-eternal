using System;
using System.IO;
using Newtonsoft.Json.Linq;
using UnityEditor;
using UnityEngine;
using UnityEngine.UIElements;

namespace Eternal.UnityMigration.Editor
{
    public static class NativeRendererVerification
    {
        public static string Verify()
        {
            if(!Application.isPlaying)throw new InvalidOperationException("Native renderer inspection requires the running review.");
            var rows=new JArray();int missingBodies=0;
            foreach(var actor in UnityEngine.Object.FindObjectsByType<PaintedActor>())
            {
                foreach(var mesh in actor.GetComponentsInChildren<MeshFilter>())
                {
                    if(mesh.name=="Original painted body"&&(mesh.sharedMesh==null||mesh.sharedMesh.vertexCount==0))missingBodies++;
                    var renderer=mesh.GetComponent<Renderer>();if(renderer==null||renderer.sharedMaterial==null)continue;var m=renderer.sharedMaterial;
                    string Vector(string key)=>m.HasProperty(key)?m.GetVector(key).ToString("F3"):"missing";
                    rows.Add(new JObject{{"actor",actor.name},{"surface",mesh.name},{"vertices",mesh.sharedMesh?.vertexCount??0},{"shader",m.shader.name},{"shader_supported",m.shader.isSupported},{"shader_errors",ShaderUtil.ShaderHasError(m.shader)},{"texture",m.mainTexture?.name??"missing"},{"atlas",Vector("_AtlasRect")},{"size",Vector("_PaintSize")},{"anchor",Vector("_Anchor")},{"tint",Vector("_Tint")},{"bounds",renderer.bounds.ToString()},{"enabled",renderer.enabled},{"layer",renderer.gameObject.layer},{"queue",m.renderQueue}});
                }
            }
            var review=UnityEngine.Object.FindAnyObjectByType<HuntingMigrationReview>();var camera=review?.BattleCamera;
            var report=new JObject{{"time_utc",DateTime.UtcNow},{"native_frames",Time.frameCount},{"surfaces",rows},{"camera_culling_mask",camera?.cullingMask??0},{"camera_position",camera?.transform.position.ToString()??"missing"},{"note","Read-only native renderer diagnostics; visibility is accepted through actual screenshot review, not these fields alone."}};
            report["empty_body_meshes"]=missingBodies;report["body_meshes_present"]=missingBodies==0;
            report["review_component_cost"]=review?.FrameCost.Snapshot();report["feedback_component_cost"]=review?.Feedback.FrameCost.Snapshot();
            report["catchup_limit_hits"]=review?.CatchupLimitHits??0;report["active_skill_effects"]=review?.Feedback.ActiveSkillEffects??0;report["skill_geometry_quads"]=review?.Feedback.SkillGeometryQuads??0;
            report["reused_enemy_views"]=review?.ReusedEnemyViews??0;
            if(review?.ReviewState!=null)
            {
                var state=review.ReviewState;
                report["session_state"]=new JObject{{"isolated_review",(bool?)state.Snapshot()["native_review_fixture"]??false},{"wallet_gold",state.WalletGold},{"wallet_gems",state.WalletGems},{"inventory_count",state.Inventory().Count},{"deployed_heroes",new JArray(state.DeployedHeroes())},{"growth_bound_to_hunting",ReferenceEquals(state,review.Simulation.PlayerState)},{"real_player_save_imported",false}};
            }
            var arena=UnityEngine.Object.FindAnyObjectByType<RaidArenaPresentation>();
            report["mode"]=review?.Raid==null?"hunt":"raid";report["raid_zone"]=review?.Raid?.Zone;
            report["painted_arena"]=arena?.PaintedMap;report["review_paused"]=review?.Raid?.Paused??review?.Simulation.Paused??false;
            int arenaSurfaces=0;
            if(arena!=null)foreach(var renderer in arena.GetComponentsInChildren<Renderer>())
            {var shader=renderer.sharedMaterial?.shader;if(shader==null||!shader.isSupported||ShaderUtil.ShaderHasError(shader))throw new InvalidOperationException("Native raid arena shader unavailable: "+renderer.name);arenaSurfaces++;}
            report["verified_arena_surfaces"]=arenaSurfaces;
            var floor=GameObject.Find("Original stone hunting field")?.GetComponent<Renderer>();var floorMaterial=floor?.sharedMaterial;var slabs=floorMaterial?.GetTexture("_PaintedMap") as Texture2D;
            if(slabs!=null)report["painted_slabs"]=new JObject{{"active",floorMaterial.GetFloat("_PaintedSlabs")>.5f},{"width",slabs.width},{"height",slabs.height},{"format",slabs.format.ToString()},{"wrap_mode",slabs.wrapMode.ToString()},{"runtime_texture_bytes",UnityEngine.Profiling.Profiler.GetRuntimeMemorySizeLong(slabs)},{"shader_supported",floorMaterial.shader.isSupported},{"shader_errors",ShaderUtil.ShaderHasError(floorMaterial.shader)}};
            var ui=review?.GetComponent<UIDocument>()?.rootVisualElement;var modal=ui?.Q("inspection");
            if(modal!=null)report["inspection_panel"]=new JObject{{"visible",modal.resolvedStyle.display==DisplayStyle.Flex},{"bounds",modal.worldBound.ToString()}};
            File.WriteAllText("../checks/unity-migration-2026-10-08/native-renderer-diagnostics.json",report.ToString());if(missingBodies>0)throw new InvalidOperationException("Native actor bodies lost their mesh buffers: "+missingBodies);return report.ToString();
        }
    }
}
