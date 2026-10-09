using System;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Animations;
using UnityEngine.Playables;
using UnityEngine.Rendering;

namespace Eternal.UnityMigration
{
    // Native imported skinned FBX, independent of PaintedActor/relief readers.
    // This first pass has real depth and bone animation; final art is pending.
    public sealed class AureliaVolumeActor : MonoBehaviour
    {
        readonly Dictionary<string,AnimationClip> clips=new(StringComparer.OrdinalIgnoreCase);
        readonly List<Material> materials=new();
        PlayableGraph graph;
        AnimationClipPlayable playback;
        AnimationPlayableOutput output;
        AnimationClip active;
        float attackUntil;
        public string HeroId {get;private set;}
        public bool HasVolume {get;private set;}
        public void Initialize(string id)
        {
            if(HasVolume)throw new InvalidOperationException("Volume actor already initialized.");
            HeroId=id;string path="Eternal/GraphicsRebuild/Heroes/"+id;
            var imported=Resources.Load<GameObject>(path);
            if(imported==null)throw new InvalidOperationException("Missing native FBX: "+path);
            var model=Instantiate(imported,transform);model.name=id+" rigged volume";
            foreach(var renderer in model.GetComponentsInChildren<Renderer>())
            {
                var converted=new Material[renderer.sharedMaterials.Length];
                for(int i=0;i<converted.Length;i++)
                {
                    var original=renderer.sharedMaterials[i];string name=original!=null?original.name:"Ivory enamel plate";
                    var data=Surface(name,id);var material=new Material(Shader.Find("Universal Render Pipeline/Lit")){name=name+" URP"};
                    material.SetColor("_BaseColor",data.color);material.SetFloat("_Metallic",data.metal);material.SetFloat("_Smoothness",1-data.rough);
                    if(name.Contains("gem",StringComparison.OrdinalIgnoreCase)){material.EnableKeyword("_EMISSION");material.SetColor("_EmissionColor",data.color*.25f);}
                    materials.Add(material);converted[i]=material;
                }
                renderer.sharedMaterials=converted;renderer.shadowCastingMode=ShadowCastingMode.On;renderer.receiveShadows=true;
            }
            foreach(var clip in Resources.LoadAll<AnimationClip>(path))
            {
                if(clip.name.StartsWith("__preview__",StringComparison.Ordinal))continue;
                foreach(string name in new[]{"Idle","Walk","Attack"})if(clip.name.Contains(name,StringComparison.OrdinalIgnoreCase))clips[name]=clip;
            }
            var animator=model.GetComponentInChildren<Animator>()??model.AddComponent<Animator>();animator.applyRootMotion=false;
            graph=PlayableGraph.Create(id+" bone animation");graph.SetTimeUpdateMode(DirectorUpdateMode.GameTime);
            output=AnimationPlayableOutput.Create(graph,"Aurelia native skeleton",animator);
            HasVolume=true;Play("Idle");graph.Play();
        }
        public void Play(string name)
        {
            if(!clips.TryGetValue(name,out var clip)||active==clip)return;
            if(playback.IsValid())graph.DestroyPlayable(playback);
            playback=AnimationClipPlayable.Create(graph,clip);playback.SetApplyFootIK(false);playback.SetDuration(double.PositiveInfinity);
            output.SetSourcePlayable(playback);active=clip;
        }
        public void Attack(){Play("Attack");if(playback.IsValid())playback.SetTime(0);attackUntil=Time.time+(active!=null?active.length:.8f);}
        void Update()
        {
            if(attackUntil>0&&Time.time>=attackUntil){attackUntil=0;Play("Idle");}
            if(active!=null&&playback.IsValid()&&attackUntil<=0&&playback.GetTime()>active.length&&active.length>0)playback.SetTime(playback.GetTime()%active.length);
        }
        static (Color color,float metal,float rough) Surface(string name,string hero)
        {
            string color="e9e3cf";float metal=0,rough=.65f;
            if(name.Contains("gold",StringComparison.OrdinalIgnoreCase)){color="c39a48";metal=.8f;rough=.3f;}
            else if(name.Contains("enamel plate")){metal=.55f;rough=.35f;}
            else if(name.Contains("steel")){color="b8cbd4";metal=.92f;rough=.2f;}
            else if(name.Contains("Blue enamel")){color="29468b";metal=.45f;rough=.4f;}
            else if(name.Contains("blue cloth"))color="21418b";
            else if(name.Contains("crimson"))color="8e242a";
            else if(name.Contains("Forest silk"))color="547c3e";
            else if(name.Contains("Ivory silk"))color="eee5cf";
            else if(name.Contains("Skin"))color="f2cab0";
            else if(name.Contains("Hair highlights"))color=hero=="leonhardt"?"f2cc7e":hero=="elisia"?"f4e7d9":"b34a3c";
            else if(name.Contains("hair"))color=hero=="leonhardt"?"d9a64d":hero=="elisia"?"e8d8c9":"923831";
            else if(name.Contains("leather"))color="30272c";
            else if(name.Contains("Iris"))color=hero=="leonhardt"?"3b80b4":hero=="elisia"?"55834c":"ac573e";
            else if(name.Contains("Dark eye"))color="171922";
            else if(name.Contains("Eye light"))color="ffffff";
            else if(name.Contains("Eye ivory"))color="f8f1df";
            else if(name.Contains("Lip"))color="a76663";
            else if(name.Contains("Green gem")){color="52ce62";metal=.3f;rough=.2f;}
            else if(name.Contains("leaf green"))color="4b7537";
            else if(name.Contains("Bowstring"))color="d0bba1";
            ColorUtility.TryParseHtmlString("#"+color,out var parsed);return(parsed,metal,rough);
        }
        void OnDestroy(){if(graph.IsValid())graph.Destroy();foreach(var material in materials)if(material!=null)Destroy(material);}
    }
}
