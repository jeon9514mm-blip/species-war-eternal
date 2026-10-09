using System;
using UnityEngine;

namespace Eternal.UnityMigration
{
    // A world-anchored painting receives existing actor shadows. It never
    // supplies collision, a movement goal, combat clock or resource reward.
    public sealed class HuntEnvironmentPresentation : MonoBehaviour
    {
        Material painting;
        Renderer surface;
        Material fallback;
        Camera view;
        Mesh motes;
        MeshRenderer moteRenderer;
        readonly Vector3[] moteVertices=new Vector3[48];
        readonly Color[] moteColors=new Color[48];
        Color moteTint;
        public string Zone {get;private set;}
        public string ArtResource {get;private set;}
        public bool HasPainting=>painting!=null&&surface.sharedMaterial==painting;
        public static string Resource(string zone)=>zone switch
        {"gray_meadow"=>"Eternal/Environment/Hunt/meadow-hunt-v1","forgotten_mine"=>"Eternal/Environment/Hunt/mine-hunt-v1","moonrest_forest"=>"Eternal/Environment/Hunt/forest-hunt-v1",_=>throw new ArgumentException("Unknown hunting region.")};
        public void Initialize(Camera camera,Renderer floor,Material stone,string zone)
        {
            surface=floor;fallback=stone;view=camera;painting=new Material(Resources.Load<Material>("Eternal/Materials/PaintedArena"));
            painting.name="Owned world-anchored hunt painting";painting.SetFloat("_WorldAnchored",1);
            // Camera breathing, impact shake and zoom move the painting and
            // actors together; screen-position UVs would make the floor slide.
            var ray=camera.ViewportPointToRay(new Vector3(.5f,.5f));var plane=new Plane(Vector3.up,Vector3.zero);
            Vector3 center=plane.Raycast(ray,out float distance)?ray.GetPoint(distance):Vector3.zero;
            painting.SetVector("_PaintingCenter",center);var right=camera.transform.right;var up=camera.transform.up;
            painting.SetVector("_PaintingRight",new Vector4(right.x,right.y,right.z,camera.orthographicSize*2*camera.aspect));
            painting.SetVector("_PaintingUp",new Vector4(up.x,up.y,up.z,camera.orthographicSize*2));Bind(zone);
            motes=new Mesh{name="Twelve regional atmosphere motes"};motes.MarkDynamic();var uv=new Vector2[48];var indices=new int[72];
            for(int i=0;i<12;i++){int v=i*4,t=i*6;uv[v]=Vector2.zero;uv[v+1]=Vector2.up;uv[v+2]=Vector2.one;uv[v+3]=Vector2.right;indices[t]=v;indices[t+1]=v+1;indices[t+2]=v+2;indices[t+3]=v;indices[t+4]=v+2;indices[t+5]=v+3;}
            motes.vertices=moteVertices;motes.colors=moteColors;motes.uv=uv;motes.triangles=indices;motes.bounds=new Bounds(Vector3.zero,new Vector3(40,8,30));
            var atmosphere=new GameObject("Regional atmosphere");atmosphere.transform.SetParent(transform,false);atmosphere.AddComponent<MeshFilter>().sharedMesh=motes;moteRenderer=atmosphere.AddComponent<MeshRenderer>();moteRenderer.sharedMaterial=Resources.Load<Material>("Eternal/Materials/Particles");
        }
        public void Bind(string zone)
        {
            string path=Resource(zone);var art=Resources.Load<Texture2D>(path);Zone=zone;ArtResource=path;
            moteTint=zone=="gray_meadow"?new Color(.80f,.78f,.50f,.24f):zone=="forgotten_mine"?new Color(.80f,.65f,.41f,.18f):new Color(.57f,.66f,.95f,.25f);
            if(art==null){surface.sharedMaterial=fallback;return;}
            painting.SetTexture("_MainTex",art);painting.SetColor("_Tint",Color.white);surface.sharedMaterial=painting;
        }
        void LateUpdate()
        {
            if(motes==null||surface==null)return;moteRenderer.enabled=surface.gameObject.activeSelf;if(!moteRenderer.enabled)return;
            float now=Time.unscaledTime;var right=view.transform.right;var up=view.transform.up;
            for(int i=0;i<12;i++)
            {
                float phase=Mathf.Repeat(now*.025f+i*.618034f,1);var center=new Vector3(-13+i%6*4.8f+Mathf.Sin(now*.23f+i)*.55f,.2f+phase*.65f,-6+i/6*10+Mathf.Sin(now*.16f+i)*.8f);
                float size=.023f+i%3*.006f;int v=i*4;moteVertices[v]=center-right*size-up*size;moteVertices[v+1]=center-right*size+up*size;moteVertices[v+2]=center+right*size+up*size;moteVertices[v+3]=center+right*size-up*size;
                var color=moteTint;color.a*=Mathf.Sin(phase*Mathf.PI);moteColors[v]=moteColors[v+1]=moteColors[v+2]=moteColors[v+3]=color;
            }
            motes.vertices=moteVertices;motes.colors=moteColors;
        }
        void OnDestroy(){if(painting!=null)Destroy(painting);if(motes!=null)Destroy(motes);}
    }
}
