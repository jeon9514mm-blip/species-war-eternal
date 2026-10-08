using System;
using System.IO;
using Newtonsoft.Json.Linq;
using UnityEditor;
using UnityEngine;

namespace Eternal.UnityMigration.Editor
{
    public static class NativeRendererVerification
    {
        public static string Verify()
        {
            if(!Application.isPlaying)throw new InvalidOperationException("Native renderer inspection requires the running review.");
            var rows=new JArray();
            foreach(var actor in UnityEngine.Object.FindObjectsByType<PaintedActor>(FindObjectsSortMode.None))
            {
                foreach(var mesh in actor.GetComponentsInChildren<MeshFilter>())
                {
                    var renderer=mesh.GetComponent<Renderer>();if(renderer==null||renderer.sharedMaterial==null)continue;var m=renderer.sharedMaterial;
                    string Vector(string key)=>m.HasProperty(key)?m.GetVector(key).ToString("F3"):"missing";
                    rows.Add(new JObject{{"actor",actor.name},{"surface",mesh.name},{"vertices",mesh.sharedMesh?.vertexCount??0},{"shader",m.shader.name},{"shader_supported",m.shader.isSupported},{"shader_errors",ShaderUtil.ShaderHasError(m.shader)},{"texture",m.mainTexture?.name??"missing"},{"atlas",Vector("_AtlasRect")},{"size",Vector("_PaintSize")},{"anchor",Vector("_Anchor")},{"tint",Vector("_Tint")},{"bounds",renderer.bounds.ToString()},{"enabled",renderer.enabled},{"layer",renderer.gameObject.layer},{"queue",m.renderQueue}});
                }
            }
            var camera=UnityEngine.Object.FindFirstObjectByType<HuntingMigrationReview>()?.BattleCamera;
            var report=new JObject{{"time_utc",DateTime.UtcNow},{"native_frames",Time.frameCount},{"surfaces",rows},{"camera_culling_mask",camera?.cullingMask??0},{"camera_position",camera?.transform.position.ToString()??"missing"},{"note","Read-only native renderer diagnostics; visibility is accepted through actual screenshot review, not these fields alone."}};
            File.WriteAllText("../checks/unity-migration-2026-10-08/native-renderer-diagnostics.json",report.ToString());return report.ToString();
        }
    }
}
