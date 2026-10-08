using System;
using System.Collections.Generic;
using UnityEngine;

namespace Eternal.UnityMigration
{
    // An asset migration review scene, intentionally not labelled as the finished game.
    public sealed class OriginalAssetVerification : MonoBehaviour
    {
        public int VerifiedActorCount { get; private set; }
        public int AnimationFrames { get; private set; }
        readonly List<PaintedActor> actors = new();
        Camera cameraView;
        double startTime;

        void Start()
        {
            startTime = Time.realtimeSinceStartupAsDouble;
            Application.targetFrameRate = 60;
            var cameraObject = new GameObject("45 degree original art review");
            cameraView = cameraObject.AddComponent<Camera>();
            cameraView.orthographic = true;
            cameraView.orthographicSize = 17;
            cameraView.backgroundColor = new Color(.035f,.045f,.055f);
            cameraView.transform.position = new Vector3(0,28,-28);
            cameraView.transform.LookAt(Vector3.zero);
            cameraObject.AddComponent<AudioListener>();
            var sun = new GameObject("Sun").AddComponent<Light>();
            sun.type = LightType.Directional; sun.intensity = .9f;
            sun.transform.rotation = Quaternion.Euler(50,-25,0);
            var floor = GameObject.CreatePrimitive(PrimitiveType.Plane);
            floor.name="Original 1024 stone floor";
            floor.transform.localScale = new Vector3(5,1,5);
            var floorMaterial = new Material(Shader.Find("Universal Render Pipeline/Lit"));
            floorMaterial.SetTexture("_BaseMap", Resources.Load<Texture2D>("Eternal/Floor/stone_1024_albedo_ao"));
            floorMaterial.SetTexture("_BumpMap", Resources.Load<Texture2D>("Eternal/Floor/stone_1024_normal"));
            floorMaterial.EnableKeyword("_NORMALMAP");
            floorMaterial.SetFloat("_Smoothness",.42f); floorMaterial.SetFloat("_Metallic",.32f);
            floorMaterial.SetTextureScale("_BaseMap",new Vector2(5,5));
            floor.GetComponent<Renderer>().sharedMaterial=floorMaterial;
            var entries = OriginalCatalog.Actors.entries;
            for (int i=0;i<entries.Length;i++)
            {
                var actor = new GameObject(entries[i].id).AddComponent<PaintedActor>();
                actor.transform.position = new Vector3((i%10-4.5f)*4,0,(i/10-2)*6);
                actor.Initialize(entries[i].id, entries[i].hero ? 2.4f : 2.0f, cameraView,entries[i].hero);
                actors.Add(actor);
            }
            VerifiedActorCount=actors.Count;
            Debug.Log("ETERNAL_ASSET_REVIEW_RUNNING: " + VerifiedActorCount + " original actors. Gameplay migration remains separate.");
        }
        void Update() { AnimationFrames++; }
        void OnGUI()
        {
            GUI.color=new Color(.85f,.83f,.76f);
            GUI.Label(new Rect(18,12,1000,30), "UNITY / ORIGINAL ASSET VERIFICATION — 30 HEROES / 120 SKILLS / " + VerifiedActorCount + " ACTORS");
            GUI.Label(new Rect(18,36,1000,30), "Animated atlas + stable original anchors + 45 degree camera | frame " + AnimationFrames + " | " + (Time.realtimeSinceStartupAsDouble-startTime).ToString("F1") + "s");
        }
    }

    public sealed class PaintedActor : MonoBehaviour
    {
        AtlasDefinition atlas;
        MeshFilter meshFilter;
        MeshRenderer meshRenderer;
        Mesh[] frames;
        Camera cameraView;
        int frame;
        float phase;
        public bool Driven;
        public Vector2 Facing=Vector2.right;
        public float MovingSpeed,AttackSeconds,HitSeconds;
        float traveled;
        bool relief,heroSurface;
        float displayHeight;
        string actorId;
        MeshFilter hairFilter;
        MeshRenderer hairRenderer;
        readonly CapeChainMotion cape=new();
        static readonly int[] capeProperties={Shader.PropertyToID("_Cape0"),Shader.PropertyToID("_Cape1"),Shader.PropertyToID("_Cape2"),Shader.PropertyToID("_Cape3"),Shader.PropertyToID("_Cape4")};
        public bool UsesRelief=>relief;
        public string ActorId=>actorId;
        public bool IsHero=>heroSurface;
        public int BodyTriangles=>meshFilter?.sharedMesh?.triangles.Length/3??0;
        public int HairCards=>hairFilter?.sharedMesh?.triangles.Length/6??0;
        public PaintedPoseSnapshot CapturePose()
        {
            var set=frame<atlas.attack.frames.Length?atlas.attack:atlas.motion;
            var pose=set.frames[frame<atlas.attack.frames.Length?frame:frame-atlas.attack.frames.Length];
            return new PaintedPoseSnapshot(meshRenderer.sharedMaterial.mainTexture,meshFilter.transform,pose,displayHeight/set.native_height,meshRenderer.sortingOrder);
        }

        public void Initialize(string id,float height,Camera camera,bool hero=false)
        {
            actorId=id;cameraView=camera; atlas=OriginalCatalog.Atlas(id);displayHeight=height;heroSurface=hero;
            var art = new GameObject("Original painted body");
            art.transform.SetParent(transform,false);
            meshFilter=art.AddComponent<MeshFilter>(); meshRenderer=art.AddComponent<MeshRenderer>();
            var reliefTemplate=Resources.Load<Material>("Eternal/Materials/ReliefPaint");
            var surfaces=reliefTemplate!=null?OriginalReliefMesh.Load(id):null;relief=surfaces!=null;
            var template=relief?reliefTemplate:Resources.Load<Material>("Eternal/Materials/OriginalPaint");
            var shader=Shader.Find("Eternal/OriginalPaint") ?? throw new InvalidOperationException("Original paint shader missing");
            var material=template!=null?new Material(template):new Material(shader);
            material.mainTexture=Resources.Load<Texture2D>("Eternal/Actors/"+id+"/poses") ?? throw new InvalidOperationException("Atlas missing: "+id);
            meshRenderer.sharedMaterial=material;
            meshRenderer.sortingOrder=1000-Mathf.RoundToInt(transform.position.z*10);
            if(relief)
            {
                meshFilter.sharedMesh=surfaces.Body;meshRenderer.shadowCastingMode=UnityEngine.Rendering.ShadowCastingMode.On;
                material.SetFloat("_CapeEnabled",hero?1:0);
                if(hero&&surfaces.Hair!=null)
                {
                    var hair=new GameObject("600 original Blender hair cards");hair.transform.SetParent(art.transform,false);
                    hairFilter=hair.AddComponent<MeshFilter>();hairFilter.sharedMesh=surfaces.Hair;hairRenderer=hair.AddComponent<MeshRenderer>();
                    var hairMaterial=new Material(material);hairMaterial.SetFloat("_HairCards",1);hairMaterial.SetFloat("_Outline",0);hairMaterial.SetFloat("_CapeEnabled",0);hairRenderer.sharedMaterial=hairMaterial;
                }
                SetReliefPose(0);phase=(transform.position.x+20)*.08f;return;
            }
            frames=new Mesh[atlas.attack.frames.Length+atlas.motion.frames.Length];
            int index=0;
            foreach(var set in new[]{atlas.attack,atlas.motion})
            foreach(var f in set.frames)
            {
                float k=height/set.native_height;
                float left=-f.anchor[0]*k, right=(f.region[2]-f.anchor[0])*k;
                float bottom=(f.anchor[1]-f.region[3])*k, top=f.anchor[1]*k;
                float u=f.region[0]/1024, v=1-(f.region[1]+f.region[3])/1024, w=f.region[2]/1024, h=f.region[3]/1024;
                var mesh=new Mesh { name=id+" original pose "+index };
                mesh.vertices=new[]{new Vector3(left,bottom,0),new Vector3(left,top,0),new Vector3(right,top,0),new Vector3(right,bottom,0)};
                mesh.uv=new[]{new Vector2(u,v),new Vector2(u,v+h),new Vector2(u+w,v+h),new Vector2(u+w,v)};
                mesh.triangles=new[]{0,1,2,0,2,3}; mesh.RecalculateBounds();
                frames[index++]=mesh;
            }
            meshFilter.sharedMesh=frames[0];
            phase=(transform.position.x+20)*.08f;
        }
        void LateUpdate()
        {
            if(frames==null&&!relief)return;
            AttackSeconds=Mathf.Max(0,AttackSeconds-Time.unscaledDeltaTime);HitSeconds=Mathf.Max(0,HitSeconds-Time.unscaledDeltaTime);
            traveled+=MovingSpeed*Time.unscaledDeltaTime;
            int next=Driven?PoseIndex(atlas,MovingSpeed,traveled,AttackSeconds,HitSeconds,Time.unscaledTime+phase):(int)((Time.time+phase)*5)%(atlas.attack.frames.Length+atlas.motion.frames.Length);
            next=Mathf.Clamp(next,0,atlas.attack.frames.Length+atlas.motion.frames.Length-1);
            if(next!=frame){frame=next;if(relief)SetReliefPose(frame);else meshFilter.sharedMesh=frames[frame];}
            // Relief breathing is applied above the foot anchor in the shader.
            // The root, silhouette scale and ground contact never bob together.
            meshFilter.transform.rotation=cameraView.transform.rotation;
            meshFilter.transform.localPosition=Vector3.zero;
            if(Driven&&Mathf.Abs(Facing.x)>.08f)meshFilter.transform.localScale=new Vector3(Facing.x<0?-1:1,1,1);
            meshRenderer.sortingOrder=1000-Mathf.RoundToInt(transform.position.z*10);
            meshRenderer.sharedMaterial.SetColor("_Tint",HitSeconds>0?new Color(1.5f,1.5f,1.5f,1):Color.white);
            if(relief)
            {
                var material=meshRenderer.sharedMaterial;material.SetFloat("_VisualTime",Time.unscaledTime);
                float period=heroSurface?2:actorId.Contains("boar")?2.2f:actorId.Contains("crow")?1.5f:1.2f;
                float breath=MovingSpeed>.05f||AttackSeconds>0?0:Mathf.Sin((Time.unscaledTime+phase)*Mathf.PI*2/period)*2.5f*displayHeight/86.4f;
                material.SetFloat("_Breath",breath);
                if(heroSurface)
                {cape.Advance(Time.unscaledDeltaTime,Time.unscaledTime,Mathf.Clamp01(MovingSpeed/2.2f),phase);for(int i=0;i<5;i++){var p=cape.Points[i]*displayHeight/86.4f;material.SetVector(capeProperties[i],new Vector4(p.x,-p.y,0,0));}}
                if(hairRenderer!=null){hairRenderer.sharedMaterial.SetFloat("_VisualTime",Time.unscaledTime);hairRenderer.sharedMaterial.SetFloat("_Breath",breath);hairRenderer.sharedMaterial.SetColor("_Tint",material.GetColor("_Tint"));}
            }
        }
        void SetReliefPose(int index)
        {
            var set=index<atlas.attack.frames.Length?atlas.attack:atlas.motion;var f=set.frames[index<atlas.attack.frames.Length?index:index-atlas.attack.frames.Length];
            float k=displayHeight/set.native_height;
            void Configure(Material material)
            {
                material.SetVector("_AtlasRect",new Vector4(f.region[0]/1024,1-f.region[1]/1024,f.region[2]/1024,f.region[3]/1024));
                material.SetVector("_PaintSize",new Vector4(f.region[2]*k,f.region[3]*k,displayHeight/86.4f,0));material.SetVector("_Anchor",new Vector4(f.anchor[0]*k,f.anchor[1]*k,0,0));
                var h=f.hair_rect;material.SetVector("_HairRect",h?.Length==4?new Vector4(h[0],h[1],h[2],h[3]):new Vector4(.1f,0,.8f,.3f));
            }
            Configure(meshRenderer.sharedMaterial);meshRenderer.sharedMaterial.SetFloat("_Outline",heroSurface?3*f.region[3]/86.4f:0);
            // The shader remaps normalized source vertices to each pose. A
            // shared 12m mesh bound keeps distant cards in every shadow/frustum.
            // Renderer-local bounds retain the entire painted pose plus its
            // bounded cape/hair/breath displacement without changing the cache.
            var bounds=new Bounds(new Vector3((f.region[2]*.5f-f.anchor[0])*k,(f.anchor[1]-f.region[3]*.5f)*k,0),new Vector3(f.region[2]*k+.28f,f.region[3]*k+.28f,.35f));
            meshRenderer.localBounds=bounds;
            if(hairRenderer!=null){Configure(hairRenderer.sharedMaterial);hairRenderer.localBounds=bounds;}
        }
        public static int PoseIndex(AtlasDefinition data,float movingSpeed,float distance,float attack,float hit,float idleTime)
        {
            if(hit>0)return data.attack.frames.Length+Mathf.Min(6,data.motion.frames.Length-1);
            if(attack>0)return Mathf.Clamp((int)((.32f-attack)/.32f*data.attack.frames.Length),0,data.attack.frames.Length-1);
            int motion=movingSpeed>.05f?2+(int)(distance*5)%4:(int)(idleTime*2)%2;
            return data.attack.frames.Length+Mathf.Min(motion,data.motion.frames.Length-1);
        }
        void OnDestroy()
        {
            if(frames!=null)foreach(var mesh in frames)Destroy(mesh);
            if(meshRenderer!=null)Destroy(meshRenderer.sharedMaterial);
            if(hairRenderer!=null)Destroy(hairRenderer.sharedMaterial);
        }
    }
}
