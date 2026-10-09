using UnityEngine;

namespace Eternal.UnityMigration
{
    // Six sparse painted silhouette shells. A 2.5D fur approximation rather
    // than a volumetric groom or six duplicated opaque character paintings.
    public sealed class PaintedFurShells : MonoBehaviour
    {
        readonly MeshRenderer[] shells=new MeshRenderer[6];
        MeshRenderer body;
        public int Layers=>body!=null?6:0;
        public static bool Suitable(string id)=>id is "ragna" or "fenris" or "garm" or "ulric" or "bora" or "fallen_werewolf" or "moon_wolf" or "frost_deer"||id.Contains("boar")||id.Contains("dog");
        public void Initialize(MeshFilter source,MeshRenderer renderer)
        {
            body=renderer;
            for(int i=0;i<6;i++)
            {
                var shell=new GameObject("Painted fur shell "+(i+1));shell.transform.SetParent(source.transform,false);shell.AddComponent<MeshFilter>().sharedMesh=source.sharedMesh;
                var r=shell.AddComponent<MeshRenderer>();r.sharedMaterial=new Material(renderer.sharedMaterial);r.sharedMaterial.SetFloat("_FurShell",(i+1)/6f);r.shadowCastingMode=UnityEngine.Rendering.ShadowCastingMode.Off;r.receiveShadows=true;shells[i]=r;
            }
        }
        void LateUpdate()
        {
            if(body==null)return;
            for(int i=0;i<6;i++){var r=shells[i];r.sharedMaterial.CopyPropertiesFromMaterial(body.sharedMaterial);r.sharedMaterial.SetFloat("_FurShell",(i+1)/6f);r.sortingOrder=body.sortingOrder+1;r.localBounds=body.localBounds;}
        }
        void OnDestroy(){foreach(var r in shells)if(r!=null)Destroy(r.sharedMaterial);}
    }
}
