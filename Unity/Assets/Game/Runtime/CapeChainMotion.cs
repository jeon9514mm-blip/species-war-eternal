using UnityEngine;

namespace Eternal.UnityMigration
{
    // Analytic five-control strip from the original renderer, not a full cloth
    // surface solver. Pinned root, torso avoidance and non-adjacent separation.
    public sealed class CapeChainMotion
    {
        public readonly Vector2[] Points=new Vector2[5];
        readonly Vector2[] velocities=new Vector2[5],chain=new Vector2[5];
        public int CollisionCorrections {get;private set;}
        public void Advance(float delta,float time,float movement,float seed)
        {
            float dt=Mathf.Clamp(delta,0,.04f);if(dt<=0)return;
            for(int i=0;i<5;i++)chain[i]=new Vector2(0,i*2.2f)+Points[i];chain[0]=Points[0]=velocities[0]=Vector2.zero;
            for(int i=1;i<5;i++)
            {
                float weight=i/4f;var target=new Vector2(Mathf.Sin(time*2.3f+seed-weight*2.2f)*(1.25f+movement*.6f)*weight+Mathf.Sin(time*1.1f+seed)*.12f*weight,Mathf.Cos(time*1.6f+seed-weight*1.6f)*.18f*weight);
                velocities[i]+=(target-Points[i])*(.12f*240)*dt;velocities[i]*=Mathf.Pow(.88f,dt*60);chain[i]+=velocities[i]*dt;
            }
            for(int pass=0;pass<3;pass++)
            {
                chain[0]=Vector2.zero;
                for(int i=1;i<5;i++)
                {
                    var link=chain[i]-chain[i-1];float length=link.magnitude;
                    if(length>.00001f){var correction=link*(1-2.2f/length);chain[i]-=correction*(i==1?1:.5f);if(i>1)chain[i-1]+=correction*.5f;}
                    var center=new Vector2(-.85f,2.2f);var away=chain[i]-center;
                    if(away.magnitude<.72f){chain[i]=center+(away.sqrMagnitude>.0000001f?away.normalized:Vector2.right)*.72f;CollisionCorrections++;}
                }
                for(int i=1;i<5;i++)for(int j=i+2;j<5;j++)
                {var apart=chain[j]-chain[i];float length=apart.magnitude;if(length<.8f){var correction=(length>.00001f?apart.normalized:Vector2.down)*(.8f-length)*.5f;chain[j]+=correction;chain[i]-=correction;CollisionCorrections++;}}
            }
            for(int i=1;i<5;i++){var previous=Points[i];Points[i]=Vector2.ClampMagnitude(chain[i]-new Vector2(0,i*2.2f),2.6f);velocities[i]=(Points[i]-previous)/dt;}
        }
    }
}
