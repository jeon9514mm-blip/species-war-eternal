using System;
using System.Collections.Generic;
using Newtonsoft.Json.Linq;
using UnityEngine;

namespace Eternal.UnityMigration
{
    // Bounded observers: no combat clocks, player state or settlement logic.
    public sealed class HuntingFeedback : MonoBehaviour
    {
        struct Spark {public Vector3 position,velocity;public Color color;public float remaining,total,size;}
        struct Popup {public Vector3 position;public string text;public Color color;public float remaining,lastEvent;public int target,amount;public bool critical;}
        readonly Spark[] sparks=new Spark[320];
        readonly Popup[] popups=new Popup[32];
        readonly Vector3[] vertices=new Vector3[1280];
        readonly Color[] colors=new Color[1280];
        readonly Dictionary<string,JObject> profiles=new();
        readonly Dictionary<string,AudioClip> audio=new();
        readonly List<LineRenderer> rings=new();
        readonly List<LineRenderer> ringHalos=new();
        readonly AudioSource[] voices=new AudioSource[8];
        readonly System.Random rng=new(74013);
        Camera cameraView;
        Material particleMaterial,shadowMaterial,runeMaterial,runeGlowMaterial;
        Mesh particleMesh;
        Mesh glyphMesh;
        GameObject paintedSeal;
        public bool PaintedGroundSealVisible=>paintedSeal!=null&&paintedSeal.activeInHierarchy;
        SkillVfxBatch skillBatch;
        public bool RaidWarningVisible;
        public bool SuppressCombatPopups;
        public int ActiveSkillEffects=>skillBatch?.ActiveEffects??0;
        public int SkillGeometryQuads=>skillBatch?.Quads??0;
        public int AccentSkillQuads=>skillBatch?.AccentQuads??0;
        public int PaintedImpactQuads=>skillBatch?.PaintedImpactQuads??0;
        public int PaintedChargeQuads=>skillBatch?.PaintedChargeQuads??0;
        public int PaintedFlightQuads=>skillBatch?.PaintedFlightQuads??0;
        public int PaintedTailQuads=>skillBatch?.PaintedTailQuads??0;
        public readonly FrameBudgetProbe FrameCost=new();
        readonly Vector3[] glyphVertices=new Vector3[12*7*4];
        readonly Color[] glyphColors=new Color[12*7*4];
        Vector2 expeditionCenter=new(-3,0),targetCenter=new(-3,0);
        bool raidMode;
        Texture2D shadowTexture;
        Font outfit;
        GUIStyle damageStyle;
        readonly Rect[] damageRects=new Rect[32];
        readonly GUIContent damageContent=new();
        Vector3 baseCamera;
        float baseSize,shakeUntil,shakePixels,zoomUntil,nextStrongImpact,screenFlash;
        bool expandedHunt;
        float huntZoom=1f;
        public float HuntZoom=>huntZoom;
        public void ConfigureExpandedHunt(bool enabled){expandedHunt=enabled;}
        public void SetHuntZoom(float value){if(value!=1&&value!=1.5f&&value!=2&&value!=3)return;huntZoom=value;}
        int sparkCursor,popupCursor,voiceCursor;
        public int ActiveParticles {get;private set;}
        public int EventsPresented {get;private set;}
        public void SetRaidMode(bool raid)
        {raidMode=raid;RaidWarningVisible=false;skillBatch?.Clear();if(paintedSeal!=null)paintedSeal.SetActive(!raid);foreach(var ring in rings)ring.gameObject.SetActive(!raid);foreach(var halo in ringHalos)halo.gameObject.SetActive(!raid);if(glyphMesh!=null)transform.Find("Twelve bronze rune batch").gameObject.SetActive(!raid);Array.Clear(popups,0,popups.Length);Array.Clear(sparks,0,sparks.Length);}
        public void SetExpeditionCenter(Vector2 center){targetCenter=center;}
        public void Initialize(Camera camera)
        {
            cameraView=camera;baseCamera=camera.transform.position;baseSize=camera.orthographicSize;
            var legacy=JObject.Parse(OriginalCatalog.Required("legacy-catalogs").text);
            foreach(JObject p in legacy["skill_vfx"])profiles[(string)p["signature"]]=p;
            particleMaterial=Resources.Load<Material>("Eternal/Materials/Particles");
            skillBatch=new SkillVfxBatch(transform,particleMaterial,(JArray)legacy["skill_vfx"],camera);
            particleMesh=new Mesh{name="Bounded skill particles"};particleMesh.MarkDynamic();
            var uv=new Vector2[1280];var triangles=new int[1920];
            for(int i=0;i<320;i++)
            {int v=i*4,t=i*6;uv[v]=Vector2.zero;uv[v+1]=Vector2.up;uv[v+2]=Vector2.one;uv[v+3]=Vector2.right;triangles[t]=v;triangles[t+1]=v+1;triangles[t+2]=v+2;triangles[t+3]=v;triangles[t+4]=v+2;triangles[t+5]=v+3;}
            particleMesh.vertices=vertices;particleMesh.colors=colors;particleMesh.uv=uv;particleMesh.triangles=triangles;particleMesh.bounds=new Bounds(Vector3.zero,new Vector3(60,30,60));
            var batch=new GameObject("Skill particle batch");batch.transform.SetParent(transform,false);batch.AddComponent<MeshFilter>().sharedMesh=particleMesh;batch.AddComponent<MeshRenderer>().sharedMaterial=particleMaterial;
            shadowTexture=new Texture2D(64,64,TextureFormat.RGBA32,false);
            var pixels=new Color[4096];for(int y=0;y<64;y++)for(int x=0;x<64;x++){float r=Vector2.Distance(new Vector2(x,y),new Vector2(31.5f,31.5f))/32;pixels[y*64+x]=new Color(1,1,1,Mathf.Clamp01((1-r)*2.2f));}
            shadowTexture.SetPixels(pixels);shadowTexture.Apply();
            shadowMaterial=new Material(Resources.Load<Material>("Eternal/Materials/OriginalPaint"));shadowMaterial.mainTexture=shadowTexture;shadowMaterial.SetColor("_Tint",new Color(.015f,.02f,.015f,.7f));
            outfit=Resources.Load<Font>("Eternal/Fonts/Outfit-ExtraBold");
            for(int i=0;i<8;i++){var voice=new GameObject("Bounded positional voice "+i);voice.transform.SetParent(transform,false);voices[i]=voice.AddComponent<AudioSource>();voices[i].playOnAwake=false;voices[i].spatialBlend=.4f;voices[i].volume=.14f;}
            CreateCircle();
        }
        public void AddShadow(Transform actor,float width)
        {
            var shadow=GameObject.CreatePrimitive(PrimitiveType.Quad);shadow.name="Ground contact shadow";Destroy(shadow.GetComponent<Collider>());
            shadow.transform.SetParent(actor,false);shadow.transform.localPosition=new Vector3(0,-.015f,.12f);shadow.transform.localRotation=Quaternion.Euler(90,0,0);shadow.transform.localScale=new Vector3(width*2,width*1.1f,1);shadow.GetComponent<Renderer>().sharedMaterial=shadowMaterial;
        }
        void CreateCircle()
        {
            var painted=Resources.Load<Material>("Eternal/Materials/PaintedGroundSeal");
            if(painted!=null&&painted.mainTexture!=null)
            {
                paintedSeal=GameObject.CreatePrimitive(PrimitiveType.Quad);paintedSeal.name="Painted moss bronze ground seal";Destroy(paintedSeal.GetComponent<Collider>());
                paintedSeal.transform.SetParent(transform,false);paintedSeal.transform.localRotation=Quaternion.Euler(90,0,0);paintedSeal.transform.localScale=new Vector3(8.8f,8.8f*1.42f,1);
                var renderer=paintedSeal.GetComponent<Renderer>();renderer.sharedMaterial=painted;renderer.shadowCastingMode=UnityEngine.Rendering.ShadowCastingMode.Off;renderer.receiveShadows=false;
                return;
            }
            runeMaterial=new Material(particleMaterial);runeMaterial.SetFloat("_SoftDot",0);
            // Preserve moss/bronze hue. Raising every channel above 1 without
            // tone mapping clipped the previous circles to plain white.
            runeMaterial.SetColor("_Tint",new Color(1.15f,1.15f,1.15f,1));runeMaterial.renderQueue=2988;
            runeGlowMaterial=new Material(particleMaterial);runeGlowMaterial.SetFloat("_SoftDot",0);runeGlowMaterial.SetFloat("_SoftLine",1);runeGlowMaterial.renderQueue=2987;
            for(int ring=0;ring<3;ring++)
            {
                var line=new GameObject("Moss bronze expedition rune "+ring).AddComponent<LineRenderer>();line.transform.SetParent(transform,false);
                line.sharedMaterial=runeMaterial;line.useWorldSpace=true;line.loop=true;line.positionCount=96;line.widthMultiplier=ring==1?.036f:.075f;
                var color=ring==1?new Color(.91f,.79f,.6f,.8f):new Color(.66f,.72f,.62f,.65f);line.startColor=line.endColor=color;rings.Add(line);
                var halo=new GameObject("Soft moss bronze ring glow "+ring).AddComponent<LineRenderer>();halo.transform.SetParent(transform,false);
                halo.sharedMaterial=runeGlowMaterial;halo.useWorldSpace=true;halo.loop=true;halo.positionCount=96;halo.widthMultiplier=ring==1?.18f:.28f;
                color.a=ring==1?.20f:.28f;halo.startColor=halo.endColor=color;ringHalos.Add(halo);
            }
            glyphMesh=new Mesh{name="Twelve rotating rune glyphs"};glyphMesh.MarkDynamic();var uv=new Vector2[glyphVertices.Length];var indices=new int[glyphVertices.Length/4*6];
            for(int i=0;i<glyphVertices.Length/4;i++){int v=i*4,t=i*6;uv[v]=Vector2.zero;uv[v+1]=Vector2.up;uv[v+2]=Vector2.one;uv[v+3]=Vector2.right;indices[t]=v;indices[t+1]=v+1;indices[t+2]=v+2;indices[t+3]=v;indices[t+4]=v+2;indices[t+5]=v+3;}
            glyphMesh.vertices=glyphVertices;glyphMesh.colors=glyphColors;glyphMesh.uv=uv;glyphMesh.triangles=indices;glyphMesh.bounds=new Bounds(Vector3.zero,new Vector3(50,4,30));
            var batch=new GameObject("Twelve bronze rune batch");batch.transform.SetParent(transform,false);batch.AddComponent<MeshFilter>().sharedMesh=glyphMesh;batch.AddComponent<MeshRenderer>().sharedMaterial=runeMaterial;
        }
        static readonly Vector2[] glyphStrokeStart={new(0,-.20f),new(0,.10f),new(0,.04f),new(-.11f,.13f),new(.09f,-.13f),new(-.08f,-.04f),new(0,-.15f)};
        static readonly Vector2[] glyphStrokeEnd={new(0,.20f),new(.12f,.19f),new(.13f,-.02f),new(0,.04f),new(0,-.04f),new(0,.07f),new(-.11f,-.08f)};
        void UpdateRunes(float now,float dt)
        {
            if(raidMode)return;expeditionCenter=Vector2.Lerp(expeditionCenter,targetCenter,1-Mathf.Exp(-dt*3));
            if(paintedSeal!=null){paintedSeal.transform.position=new Vector3(expeditionCenter.x,.018f,expeditionCenter.y);return;}
            float pulse=.85f+Mathf.Sin(now*.8f)*.15f;
            for(int ring=0;ring<rings.Count;ring++)for(int i=0;i<96;i++)
            {float a=i*Mathf.PI*2/96+now*.12f*(ring%2==0?1:-1),radius=3.0f+ring*.13f;var position=new Vector3(expeditionCenter.x+Mathf.Cos(a)*radius,.015f+ring*.002f,expeditionCenter.y+Mathf.Sin(a)*radius*1.42f);rings[ring].SetPosition(i,position);ringHalos[ring].SetPosition(i,position-Vector3.up*.001f);}
            for(int rune=0;rune<12;rune++)
            {
                float a=rune*Mathf.PI*2/12+now*.12f;var radial=new Vector2(Mathf.Cos(a),Mathf.Sin(a));var tangent=new Vector2(-radial.y,radial.x);var origin=expeditionCenter+new Vector2(radial.x*3.55f,radial.y*3.55f*1.42f);
                for(int line=0;line<7;line++)
                {
                    int index=(rune*7+line)*4;var from=glyphStrokeStart[line];var to=glyphStrokeEnd[line];
                    if((line+rune)%4==0&&line>1){glyphColors[index]=glyphColors[index+1]=glyphColors[index+2]=glyphColors[index+3]=Color.clear;continue;}
                    var start=origin+tangent*from.x+radial*from.y;var end=origin+tangent*to.x+radial*to.y;var axis=(end-start).normalized;var side=new Vector2(-axis.y,axis.x)*.018f;
                    glyphVertices[index]=new Vector3(start.x-side.x,.027f,start.y-side.y);glyphVertices[index+1]=new Vector3(start.x+side.x,.027f,start.y+side.y);glyphVertices[index+2]=new Vector3(end.x+side.x,.027f,end.y+side.y);glyphVertices[index+3]=new Vector3(end.x-side.x,.027f,end.y-side.y);
                    var color=new Color(.91f,.79f,.60f,pulse*.8f);glyphColors[index]=glyphColors[index+1]=glyphColors[index+2]=glyphColors[index+3]=color;
                }
            }
            glyphMesh.vertices=glyphVertices;glyphMesh.colors=glyphColors;
        }
        static Color Parse(JObject p,string key,Color fallback)=>ColorUtility.TryParseHtmlString((string)p?[key]??"",out var color)?color:fallback;
        public void Observe(BattleEvent e,CombatEncounter battle)
        {
            EventsPresented++;
            skillBatch.Observe(e,battle);
            var position=new Vector3(e.Position.x,.9f,e.Position.y);
            if(e.Kind=="cast"||e.Kind=="passive")
            {
                if(!profiles.TryGetValue(e.Source+":"+e.Slot,out var p))return;
                var color=Parse(p,"color",new Color(.66f,.72f,.62f));int particles=(int)(p["particles"]??16);
                // Ultra identity data remains intact; concurrency is bounded so
                // ten heroes cannot create unbounded particle/voice work.
                Burst(position,color,Math.Min(particles,e.Slot=="ultimate"?40:20),e.Slot=="ultimate"?1.8f:.8f,(string)p["motif"]);
                Play("Skills/"+e.Source+"__"+e.Slot,position,.11f);
            }
            else if(e.Kind=="monster_skill")
            {Burst(position,e.Source=="fallen_elf"?new Color(.5f,.75f,.48f):new Color(.84f,.30f,.37f),10,.65f,"spark");Play("sword",position,.09f);}
            else if(e.Kind=="damage"||e.Kind=="critical"||e.Kind=="hero_hit")
            {
                bool critical=e.Kind=="critical";var color=critical?new Color(1,.84f,0):e.Kind=="hero_hit"?new Color(.86f,.54f,.48f):new Color(.85f,.84f,.8f);
                if(e.Amount>0)AddDamagePopup(e.TargetSerial,e.Amount,critical,position,color);
                Burst(position,critical?color:new Color(.77f,.64f,.52f),critical?20:5,.55f,"spark");
                float now=Time.unscaledTime;if(now>=nextStrongImpact)
                {shakePixels=RaidWarningVisible?0:critical?5:2;shakeUntil=now+.08f;nextStrongImpact=now+.20f;if(critical&&!RaidWarningVisible){zoomUntil=now+.1f;screenFlash=.04f;}}
                Play(critical?"critical":"sword",position,.08f);
            }
            else if(e.Kind=="loot")
            {
                var rewardPosition=new Vector3(targetCenter.x,1.2f,targetCenter.y);var bronze=new Color(.77f,.64f,.52f);
                Burst(rewardPosition,bronze,20,1.4f,"beam");Play("reward",rewardPosition,.17f);
                popups[popupCursor++%popups.Length]=new Popup{position=rewardPosition,text="+"+e.Amount.ToString("N0")+" G",color=bronze,remaining=.8f,lastEvent=Time.unscaledTime};
            }
            else if(e.Kind=="heal"||e.Kind=="shield")Burst(position,new Color(.66f,.78f,.65f),6,.5f,e.Kind);
            else if(e.Kind=="warning")Play("boss_warning",position,.22f);
            else if(e.Kind=="interrupt"||e.Kind=="counter"||e.Kind=="shield_break")
            {Burst(position,new Color(.84f,.74f,.51f),32,1.6f,"burst");Play(e.Kind=="shield_break"?"shield_break":"control",position,.18f);}
            else if(e.Kind=="victory"||e.Kind=="defeat")Play(e.Kind,position,.25f);
        }
        void AddDamagePopup(int target,int amount,bool critical,Vector3 position,Color color)
        {
            float now=Time.unscaledTime;int neighbors=0;
            for(int i=0;i<popups.Length;i++)
            {
                var popup=popups[i];if(popup.remaining<=0||popup.target!=target)continue;neighbors++;
                // Very short simultaneous hits share one readable number. This
                // affects presentation only; individual damage events remain intact.
                if(now-popup.lastEvent>.10f||popup.critical!=critical||popup.color!=color)continue;
                popup.amount=(int)Math.Min(int.MaxValue,(long)popup.amount+amount);popup.lastEvent=now;
                popup.text=(critical?"CRIT ":"")+popup.amount.ToString("N0");popups[i]=popup;return;
            }
            int lane=neighbors%6;float horizontal=lane switch{1=>-.6f,2=>.6f,3=>-1.1f,4=>1.1f,_=>0};
            var anchor=position+Vector3.up*.6f+cameraView.transform.right*horizontal+cameraView.transform.up*(lane/3*.45f);
            popups[popupCursor++%popups.Length]=new Popup{position=anchor,text=(critical?"CRIT ":"")+amount.ToString("N0"),color=color,remaining=.8f,lastEvent=now,target=target,amount=amount,critical=critical};
        }
        void Burst(Vector3 origin,Color color,int count,float power,string motif)
        {
            for(int i=0;i<count;i++)
            {
                double angle=i*Math.PI*2/count+rng.NextDouble()*.16;
                bool beam=motif=="beam",slash=motif=="lunge"||motif=="cleave"||motif=="fang";
                var direction=beam?Vector3.up:slash?new Vector3((float)Math.Cos(angle)*2,.25f,(float)Math.Sin(angle)*.3f):new Vector3((float)Math.Cos(angle),.4f+(float)rng.NextDouble(),(float)Math.Sin(angle));
                float lifetime=beam?.85f:.35f+(float)rng.NextDouble()*.25f;
                sparks[sparkCursor++%sparks.Length]=new Spark{position=origin,velocity=direction*power,color=color,total=lifetime,remaining=lifetime,size=beam?.05f:.025f+(float)rng.NextDouble()*.035f};
            }
        }
        void Play(string key,Vector3 position,float volume)
        {
            if(!audio.TryGetValue(key,out var clip)){clip=Resources.Load<AudioClip>("Eternal/Audio/"+key);audio[key]=clip;}
            if(clip==null)return;var voice=voices[voiceCursor++%voices.Length];if(voice.isPlaying)return;
            voice.transform.position=position;voice.pitch=.94f+(float)rng.NextDouble()*.12f;voice.PlayOneShot(clip,volume);
        }
        void LateUpdate()
        {
            if(cameraView==null)return;FrameCost.Begin();float dt=Time.unscaledDeltaTime,now=Time.unscaledTime;ActiveParticles=0;
            skillBatch.Advance(dt,RaidWarningVisible);
            var right=cameraView.transform.right;var up=cameraView.transform.up;
            for(int i=0;i<sparks.Length;i++)
            {
                var s=sparks[i];int v=i*4;s.remaining=Mathf.Max(0,s.remaining-dt);
                if(s.remaining>0){ActiveParticles++;s.velocity+=Vector3.down*.8f*dt;s.position+=s.velocity*dt;float size=s.size*Mathf.Clamp01(s.remaining/.12f);vertices[v]=s.position-right*size-up*size;vertices[v+1]=s.position-right*size+up*size;vertices[v+2]=s.position+right*size+up*size;vertices[v+3]=s.position+right*size-up*size;var c=s.color;c.a=Mathf.Clamp01(s.remaining/.15f);colors[v]=colors[v+1]=colors[v+2]=colors[v+3]=c;}
                else colors[v]=colors[v+1]=colors[v+2]=colors[v+3]=Color.clear;
                sparks[i]=s;
            }
            particleMesh.vertices=vertices;particleMesh.colors=colors;
            for(int i=0;i<popups.Length;i++){var p=popups[i];p.remaining=Mathf.Max(0,p.remaining-dt);p.position+=Vector3.up*.55f*dt;popups[i]=p;}
            float wantedSize=expandedHunt&&!raidMode?baseSize*2f/huntZoom:baseSize;
            float unit=wantedSize*2/Mathf.Max(1,Screen.height*.72f);
            float breathe=Mathf.Sin(now*Mathf.PI*2/8)*2.5f*unit;
            var shake=now<shakeUntil?new Vector3((Mathf.PerlinNoise(now*41,0)-.5f)*shakePixels*unit,(Mathf.PerlinNoise(0,now*43)-.5f)*shakePixels*unit,0):Vector3.zero;
            cameraView.transform.position=baseCamera+cameraView.transform.up*breathe+shake;
            cameraView.orthographicSize=Mathf.Lerp(cameraView.orthographicSize,now<zoomUntil?wantedSize/1.08f:wantedSize,dt*15);
            screenFlash=Mathf.Max(0,screenFlash-dt);
            UpdateRunes(now,dt);
            FrameCost.End();
        }
        void OnGUI()
        {
            if(cameraView==null||SuppressCombatPopups)return;
            damageStyle??=new GUIStyle(GUI.skin.label){font=outfit,fontSize=24,fontStyle=FontStyle.Bold,alignment=TextAnchor.MiddleCenter};
            // Player GUI skins may use black label text. GUI.color multiplies
            // that colour, so explicit white is required for coloured numbers.
            damageStyle.normal.textColor=Color.white;
            float uiScale=Screen.height/900f;damageStyle.fontSize=Mathf.RoundToInt(18*uiScale);
            int occupied=0;var viewport=cameraView.pixelRect;
            var area=new Rect(viewport.x,Screen.height-viewport.yMax,viewport.width,viewport.height);
            foreach(var p in popups)
            {
                if(p.remaining<=0)continue;var point=cameraView.WorldToScreenPoint(p.position);if(point.z<=0)continue;
                bool critical=p.text.StartsWith("CRIT ",StringComparison.Ordinal);damageStyle.fontSize=Mathf.RoundToInt(18*uiScale*(critical?1.5f:1));
                damageContent.text=p.text;var size=damageStyle.CalcSize(damageContent);
                var rect=new Rect(point.x-size.x*.5f-5*uiScale,Screen.height-point.y-size.y*.5f,size.x+10*uiScale,size.y+6*uiScale);
                rect.x=Mathf.Clamp(rect.x,area.xMin+4*uiScale,Mathf.Max(area.xMin+4*uiScale,area.xMax-rect.width-4*uiScale));
                // Resolve overlaps in actual screen pixels, including larger
                // crit labels. World-space lanes alone shrink under the camera.
                bool clear=false;
                for(int attempt=0;attempt<damageRects.Length;attempt++)
                {
                    bool collision=false;
                    for(int i=0;i<occupied;i++)if(rect.Overlaps(damageRects[i])){rect.y=damageRects[i].yMin-rect.height-5*uiScale;collision=true;break;}
                    if(rect.y<area.yMin+4*uiScale)break;
                    if(!collision){clear=true;break;}
                }
                if(!clear)continue;damageRects[occupied++]=rect;float alpha=Mathf.Clamp01(p.remaining/.15f);
                GUI.color=new Color(0,0,0,alpha*.8f);for(int i=0;i<4;i++){var outline=rect;outline.x+=(i%2==0?-3:3)*uiScale;outline.y+=(i<2?-3:3)*uiScale;GUI.Label(outline,p.text,damageStyle);}
                var color=p.color;color.a=alpha;GUI.color=color;GUI.Label(rect,p.text,damageStyle);
            }
            if(screenFlash>0){GUI.color=new Color(1,.9f,.7f,screenFlash*.8f);GUI.DrawTexture(new Rect(0,0,Screen.width,Screen.height),Texture2D.whiteTexture);}
            GUI.color=Color.white;
        }
        void OnDestroy()
        {skillBatch?.Dispose();if(particleMesh!=null)Destroy(particleMesh);if(glyphMesh!=null)Destroy(glyphMesh);if(shadowTexture!=null)Destroy(shadowTexture);if(shadowMaterial!=null)Destroy(shadowMaterial);if(runeMaterial!=null)Destroy(runeMaterial);if(runeGlowMaterial!=null)Destroy(runeGlowMaterial);}
    }
}
