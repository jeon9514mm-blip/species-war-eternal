using System;
using System.IO;
using System.Linq;
using Newtonsoft.Json.Linq;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

namespace Eternal.UnityMigration.Editor
{
    public static class PaintedImpactVerification
    {
        public static JObject Capture()
        {
            if(Application.isPlaying)throw new InvalidOperationException("Material gallery requires Edit mode.");
            var owner=new GameObject("Isolated painted impact material gallery");SkillVfxBatch batch=null;RenderTexture target=null;Texture2D pixels=null;
            try
            {
                var camera=new GameObject("Material gallery camera").AddComponent<Camera>();camera.transform.SetParent(owner.transform,false);
                camera.transform.position=new Vector3(0,.65f,-10);camera.orthographic=true;camera.orthographicSize=2.2f;camera.aspect=16f/9;camera.cullingMask=1<<30;
                camera.backgroundColor=new Color(.045f,.055f,.065f);camera.clearFlags=CameraClearFlags.SolidColor;
                camera.GetUniversalAdditionalCameraData().renderPostProcessing=false;
                var catalog=JObject.Parse(OriginalCatalog.Required("legacy-catalogs").text);
                batch=new SkillVfxBatch(owner.transform,Resources.Load<Material>("Eternal/Materials/Particles"),(JArray)catalog["skill_vfx"],camera);
                var profiles=batch.Profiles.Values;
                var selections=new[]{profiles.First(p=>p.Family==3&&p.Color.r>p.Color.b),profiles.First(p=>p.Family==4),profiles.First(p=>p.Family==0),profiles.First(p=>p.Family!=4&&p.Family!=0&&p.Family!=1&&p.Kind!="heal"&&p.Kind!="buff"&&p.Color.b>p.Color.r*1.15f)};
                var battle=new CombatEncounter();var names=new JArray();
                for(int i=0;i<selections.Length;i++)
                {
                    var profile=selections[i];var source=new Combatant{Id=profile.Hero,Serial=10+i,Position=new Vector2(-5.4f+i*3.6f,0),Hp=100};
                    battle.Heroes.Add(source);batch.Observe(new BattleEvent("cast",source,profile.Slot,source),battle);names.Add(profile.Signature);
                }
                batch.Advance(.065f,false);
                foreach(var transform in owner.GetComponentsInChildren<Transform>())transform.gameObject.layer=30;
                target=new RenderTexture(1600,450,24,RenderTextureFormat.ARGB32);target.Create();camera.aspect=1600f/450;camera.targetTexture=target;
                RenderPipeline.SubmitRenderRequest(camera,new RenderPipeline.StandardRequest{destination=target});
                var previous=RenderTexture.active;RenderTexture.active=target;pixels=new Texture2D(target.width,target.height,TextureFormat.RGBA32,false);pixels.ReadPixels(new Rect(0,0,target.width,target.height),0,0);pixels.Apply();RenderTexture.active=previous;
                string destination="../checks/unity-migration-2026-10-08/painted-impact-material-gallery.png";File.WriteAllBytes(destination,pixels.EncodeToPNG());
                var result=new JObject{{"native_material_gallery",true},{"painted_quads",batch.PaintedQuads},{"profiles",names},{"image",Path.GetFileName(destination)},{"note","Isolated Unity URP material render at a fixed timeline age. This is a shader/art inspection gallery, not a gameplay screenshot or 120-skill visual acceptance."}};
                File.WriteAllText("../checks/unity-migration-2026-10-08/painted-impact-material.json",result.ToString());return result;
            }
            finally{batch?.Dispose();if(pixels!=null)UnityEngine.Object.DestroyImmediate(pixels);if(target!=null){target.Release();UnityEngine.Object.DestroyImmediate(target);}UnityEngine.Object.DestroyImmediate(owner);}
        }
    }
}
