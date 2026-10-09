using System;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Animations;
using UnityEngine.Playables;
using UnityEngine.Rendering;
using Newtonsoft.Json.Linq;

namespace Eternal.UnityMigration
{
    // Native imported skinned FBX, independent of PaintedActor/relief readers.
    // This first pass has real depth and bone animation; final art is pending.
    public sealed class AureliaVolumeActor : MonoBehaviour
    {
        readonly Dictionary<string,AnimationClip> clips=new(StringComparer.OrdinalIgnoreCase);
        readonly List<Material> materials=new();
        PlayableGraph graph;
        AnimationClipPlayable playback,previous;
        AnimationMixerPlayable mixer;
        AnimationPlayableOutput output;
        AnimationClip active;
        Renderer[] renderers;
        readonly MaterialPropertyBlock highlight=new();
        float actionRemaining,blendTime,hitRemaining,deathTime;
        bool dead;
        public string HeroId {get;private set;}
        public bool HasVolume {get;private set;}
        public bool IsMonster {get;private set;}
        public void Initialize(string id,bool monster=false)
        {
            if(HasVolume)throw new InvalidOperationException("Volume actor already initialized.");
            HeroId=id;IsMonster=monster;string path="Eternal/GraphicsRebuild/"+(monster?"Monsters/":"Heroes/")+id;
            var imported=Resources.Load<GameObject>(path);
            if(imported==null)throw new InvalidOperationException("Missing native FBX: "+path);
            var model=Instantiate(imported,transform);model.name=id+" rigged volume";
            var manifest=Resources.Load<TextAsset>(path+"-materials");
            var surfaceData=new Dictionary<string,JObject>(StringComparer.Ordinal);
            if(manifest!=null)foreach(JObject item in (JArray)JObject.Parse(manifest.text)["materials"])surfaceData[(string)item["name"]]=item;
            var materialByName=new Dictionary<string,Material>(StringComparer.Ordinal);
            renderers=model.GetComponentsInChildren<Renderer>();
            foreach(var renderer in renderers)
            {
                var converted=new Material[renderer.sharedMaterials.Length];
                for(int i=0;i<converted.Length;i++)
                {
                    var original=renderer.sharedMaterials[i];string name=original!=null?original.name:"Ivory enamel plate";
                    if(materialByName.TryGetValue(name,out var shared)){converted[i]=shared;continue;}
                    var data=Surface(name,id);var material=new Material(Shader.Find("Universal Render Pipeline/Lit")){name=name+" URP"};
                    float emission=0;
                    if(surfaceData.TryGetValue(name,out var definition))
                    {
                        if(ColorUtility.TryParseHtmlString((string)definition["color"],out var color))data.color=color;
                        data.metal=(float?)definition["metallic"]??data.metal;data.rough=(float?)definition["roughness"]??data.rough;
                        emission=(float?)definition["emission"]??0;
                    }
                    material.SetColor("_BaseColor",data.color);material.SetFloat("_Metallic",data.metal);material.SetFloat("_Smoothness",1-data.rough);
                    material.EnableKeyword("_EMISSION");material.SetColor("_EmissionColor",data.color*emission);
                    materials.Add(material);materialByName[name]=material;converted[i]=material;
                }
                renderer.sharedMaterials=converted;renderer.shadowCastingMode=ShadowCastingMode.On;renderer.receiveShadows=true;
            }
            foreach(var clip in Resources.LoadAll<AnimationClip>(path))
            {
                if(clip.name.StartsWith("__preview__",StringComparison.Ordinal))continue;
                foreach(string name in new[]{"Idle","Walk","Attack","Skill1","Skill2","Ultimate","Death"})if(clip.name.Contains(name,StringComparison.OrdinalIgnoreCase))clips[name]=clip;
            }
            var animator=model.GetComponentInChildren<Animator>()??model.AddComponent<Animator>();animator.applyRootMotion=false;
            graph=PlayableGraph.Create(id+" bone animation");graph.SetTimeUpdateMode(DirectorUpdateMode.Manual);
            output=AnimationPlayableOutput.Create(graph,"Aurelia native skeleton",animator);
            mixer=AnimationMixerPlayable.Create(graph,2);output.SetSourcePlayable(mixer);
            HasVolume=true;Play("Idle");graph.Play();
        }
        public void Play(string name)=>Play(name,false);
        void Play(string name,bool restart)
        {
            if(!clips.TryGetValue(name,out var clip)||active==clip&&!restart)return;
            graph.Disconnect(mixer,0);graph.Disconnect(mixer,1);
            if(previous.IsValid())graph.DestroyPlayable(previous);
            previous=playback;
            playback=AnimationClipPlayable.Create(graph,clip);playback.SetApplyFootIK(false);playback.SetDuration(double.PositiveInfinity);
            if(previous.IsValid())graph.Connect(previous,0,mixer,0);
            graph.Connect(playback,0,mixer,1);blendTime=previous.IsValid()?0:.12f;
            mixer.SetInputWeight(0,previous.IsValid()?1:0);mixer.SetInputWeight(1,previous.IsValid()?0:1);active=clip;
        }
        public void Attack(string slot="basic",float actionSeconds=.5f)
        {
            if(dead)return;
            string clip=slot=="a1"?"Skill1":slot=="a2"?"Skill2":slot=="ultimate"?"Ultimate":"Attack";
            if(!clips.ContainsKey(clip))clip="Attack";Play(clip,true);actionRemaining=Mathf.Max(.15f,actionSeconds);
            if(active!=null&&playback.IsValid())playback.SetSpeed(active.length/actionRemaining);
        }
        public void Hit(){if(!dead)hitRemaining=.055f;}
        public void Die()
        {
            if(dead)return;dead=true;actionRemaining=0;deathTime=0;
            if(clips.ContainsKey("Death")){Play("Death",true);playback.SetSpeed(1);}
        }
        public void Face(Vector2 direction,float dt)
        {
            if(dead||direction.sqrMagnitude<.0001f)return;
            var rotation=Quaternion.LookRotation(new Vector3(direction.x,0,direction.y));
            transform.rotation=Quaternion.Slerp(transform.rotation,rotation,1-Mathf.Exp(-18*dt));
        }
        public void Advance(float dt,float movementSpeed,bool paused)
        {
            if(!HasVolume||paused)return;dt=Mathf.Clamp(dt,0,.1f);
            if(dead)
            {
                deathTime+=dt;
                if(active!=null&&playback.IsValid())playback.SetTime(Math.Min(playback.GetTime(),active.length));
                if(IsMonster&&deathTime>1.6f)gameObject.SetActive(false);
            }
            else if(actionRemaining>0)actionRemaining=Mathf.Max(0,actionRemaining-dt);
            else
            {
                Play(movementSpeed>.08f?"Walk":"Idle");
                if(playback.IsValid())playback.SetSpeed(movementSpeed>.08f?Mathf.Clamp(movementSpeed/1.4f,.55f,1.7f):1);
                if(active!=null&&playback.IsValid()&&active.length>0&&playback.GetTime()>active.length)playback.SetTime(playback.GetTime()%active.length);
            }
            blendTime+=dt;float mix=Mathf.Clamp01(blendTime/.12f);mixer.SetInputWeight(0,previous.IsValid()?1-mix:0);mixer.SetInputWeight(1,previous.IsValid()?mix:1);
            if(previous.IsValid()&&mix>=1){graph.Disconnect(mixer,0);graph.DestroyPlayable(previous);previous=default;}
            graph.Evaluate(dt);
            bool wasHit=hitRemaining>0;hitRemaining=Mathf.Max(0,hitRemaining-dt);
            if(wasHit)
            {
                highlight.Clear();if(hitRemaining>0)highlight.SetColor("_EmissionColor",new Color(.32f,.27f,.19f));
                foreach(var renderer in renderers)renderer.SetPropertyBlock(highlight);
            }
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
