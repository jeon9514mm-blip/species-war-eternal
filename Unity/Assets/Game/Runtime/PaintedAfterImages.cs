using UnityEngine;

namespace Eternal.UnityMigration
{
    public readonly struct PaintedPoseSnapshot
    {
        public readonly Texture Texture;
        public readonly Vector3 BottomLeft,TopLeft,TopRight,BottomRight;
        public readonly Vector4 Uv;
        public readonly int SortingOrder;
        public PaintedPoseSnapshot(Texture texture,Transform pose,PoseFrame frame,float units,int sorting)
        {
            Texture=texture;SortingOrder=sorting;
            float left=-frame.anchor[0]*units,right=(frame.region[2]-frame.anchor[0])*units;
            float bottom=(frame.anchor[1]-frame.region[3])*units,top=frame.anchor[1]*units;
            BottomLeft=pose.TransformPoint(new Vector3(left,bottom,0));TopLeft=pose.TransformPoint(new Vector3(left,top,0));
            TopRight=pose.TransformPoint(new Vector3(right,top,0));BottomRight=pose.TransformPoint(new Vector3(right,bottom,0));
            Uv=new Vector4(frame.region[0]/1024,1-(frame.region[1]+frame.region[3])/1024,frame.region[2]/1024,frame.region[3]/1024);
        }
    }
    // Fifty reusable painted quads: five snapshots over 0.40s for ten heroes.
    // No copies of the 6000-triangle body or 600 hair cards are made.
    public sealed class PaintedAfterImages : System.IDisposable
    {
        sealed class Ghost
        {
            public Mesh Mesh;public MeshRenderer Renderer;public MaterialPropertyBlock Properties=new();
            public readonly Vector3[] Vertices=new Vector3[4];public readonly Vector2[] Uv=new Vector2[4];
            public float Remaining;
        }
        readonly Ghost[] ghosts=new Ghost[50];
        readonly Material shared;
        readonly GameObject root;
        int cursor;
        bool disposed;
        public int ActiveCount {get;private set;}
        public PaintedAfterImages(Transform owner)
        {
            shared=new Material(Resources.Load<Material>("Eternal/Materials/OriginalPaint"));
            root=new GameObject("50 pooled painted afterimages");root.transform.SetParent(owner,false);
            for(int i=0;i<ghosts.Length;i++)
            {
                var child=new GameObject("Paint echo "+i);child.transform.SetParent(root.transform,false);
                var g=new Ghost{Mesh=new Mesh{name="Pooled original pose echo"},Renderer=child.AddComponent<MeshRenderer>()};g.Mesh.MarkDynamic();
                g.Mesh.vertices=g.Vertices;g.Mesh.uv=g.Uv;g.Mesh.triangles=new[]{0,1,2,0,2,3};
                child.AddComponent<MeshFilter>().sharedMesh=g.Mesh;g.Renderer.sharedMaterial=shared;g.Renderer.enabled=false;
                g.Renderer.shadowCastingMode=UnityEngine.Rendering.ShadowCastingMode.Off;g.Renderer.receiveShadows=false;ghosts[i]=g;
            }
        }
        public void Capture(PaintedPoseSnapshot pose)
        {
            if(disposed||root==null)return;
            var g=ghosts[cursor++%ghosts.Length];g.Remaining=.4f;
            g.Vertices[0]=pose.BottomLeft;g.Vertices[1]=pose.TopLeft;g.Vertices[2]=pose.TopRight;g.Vertices[3]=pose.BottomRight;
            var uv=pose.Uv;g.Uv[0]=new Vector2(uv.x,uv.y);g.Uv[1]=new Vector2(uv.x,uv.y+uv.w);g.Uv[2]=new Vector2(uv.x+uv.z,uv.y+uv.w);g.Uv[3]=new Vector2(uv.x+uv.z,uv.y);
            g.Mesh.vertices=g.Vertices;g.Mesh.uv=g.Uv;g.Mesh.RecalculateBounds();g.Renderer.sortingOrder=pose.SortingOrder-1;
            g.Properties.SetTexture("_MainTex",pose.Texture);g.Properties.SetColor("_Tint",new Color(.8f,.88f,1,.5f));g.Renderer.SetPropertyBlock(g.Properties);g.Renderer.enabled=true;
        }
        public void Advance(float dt)
        {
            if(disposed||root==null){ActiveCount=0;return;}
            ActiveCount=0;
            foreach(var g in ghosts)
            {
                if(g.Remaining<=0)continue;g.Remaining=Mathf.Max(0,g.Remaining-dt);
                if(g.Remaining<=0){g.Renderer.enabled=false;continue;}ActiveCount++;
                g.Properties.SetColor("_Tint",new Color(.8f,.88f,1,.5f*g.Remaining/.4f));g.Renderer.SetPropertyBlock(g.Properties);
            }
        }
        public void Clear(){foreach(var g in ghosts){g.Remaining=0;if(g.Renderer!=null)g.Renderer.enabled=false;}ActiveCount=0;}
        public void Dispose(){if(disposed)return;disposed=true;Clear();foreach(var g in ghosts)Release(g.Mesh);Release(shared);Release(root);}
        static void Release(Object value){if(value==null)return;if(Application.isPlaying)Object.Destroy(value);else Object.DestroyImmediate(value);}
    }
}
