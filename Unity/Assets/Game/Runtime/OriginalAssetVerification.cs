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
                actor.Initialize(entries[i].id, entries[i].hero ? 2.4f : 2.0f, cameraView);
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

        public void Initialize(string id,float height,Camera camera)
        {
            cameraView=camera; atlas=OriginalCatalog.Atlas(id);
            var art = new GameObject("Original painted body");
            art.transform.SetParent(transform,false);
            meshFilter=art.AddComponent<MeshFilter>(); meshRenderer=art.AddComponent<MeshRenderer>();
            var shader=Shader.Find("Eternal/OriginalPaint") ?? throw new InvalidOperationException("Original paint shader missing");
            var material=new Material(shader);
            material.mainTexture=Resources.Load<Texture2D>("Eternal/Actors/"+id+"/poses") ?? throw new InvalidOperationException("Atlas missing: "+id);
            meshRenderer.sharedMaterial=material;
            meshRenderer.sortingOrder=1000-Mathf.RoundToInt(transform.position.z*10);
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
            if(frames==null)return;
            int next=(int)((Time.time+phase)*5)%frames.Length;
            if(next!=frame){frame=next;meshFilter.sharedMesh=frames[frame];}
            // Feet and body scale never pulse; breathing is a small position offset.
            meshFilter.transform.rotation=cameraView.transform.rotation;
            meshFilter.transform.localPosition=new Vector3(0,Mathf.Sin((Time.time+phase)*Mathf.PI)*.04f,0);
        }
        void OnDestroy()
        {
            if(frames!=null)foreach(var mesh in frames)Destroy(mesh);
            if(meshRenderer!=null)Destroy(meshRenderer.sharedMaterial);
        }
    }
}
