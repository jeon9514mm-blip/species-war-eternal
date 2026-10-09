using System;
using UnityEngine;

namespace Eternal.UnityMigration
{
    // Authored relief-card presentation, not a skinned 3D hair/cloth solver.
    public readonly struct HeroDeepPresentation
    {
        public readonly int HairCards,CapePoints;
        public readonly float Wind,Clump,Frizz,BreathPeriod,Micro,Rim,Scatter;
        public HeroDeepPresentation(int cards,int cape,float wind=.15f,float clump=.3f,float frizz=.1f,float period=1,float micro=.12f,float rim=.25f,float scatter=.25f)
        {HairCards=cards;CapePoints=cape;Wind=wind;Clump=clump;Frizz=frizz;BreathPeriod=period;Micro=micro;Rim=rim;Scatter=scatter;}
        public static HeroDeepPresentation For(string id)=>id switch
        {
            "leonhardt"=>new(300,5,.06f),"mira"=>new(600,3),"elisia"=>new(600,5,.13f),"kairen"=>new(600,5,.10f),"orwin"=>new(200,3,.07f),
            "seria"=>new(600,3,.19f),"astel"=>new(600,5,.12f),"darius"=>new(100,3,.05f),"lunea"=>new(600,5,.14f),"caelum"=>new(600,3,.09f),
            "adrien"=>new(300,3,.08f),"tessa"=>new(400,3,.11f),"naia"=>new(600,5,.16f),"sael"=>new(600,5,.18f),"odelia"=>new(600,5,.10f),
            "valeria"=>new(600,5,.14f),"morgas"=>new(300,5,.08f),"ragna"=>new(400,3,.17f),"bron"=>new(400,3,.10f),"nyx"=>new(600,5,.12f),
            "fenris"=>new(600,3,.17f),"isolde"=>new(600,5,.11f),"garm"=>new(400,3,.14f),"veyra"=>new(600,3,.16f),"ulric"=>new(400,5,.12f),
            "lucien"=>new(300,5,.08f),"corvin"=>new(600,5,.16f),"rokan"=>new(400,3,.15f),"bora"=>new(600,3,.13f),"selene"=>new(600,5,.14f),
            _=>throw new ArgumentException("Unknown original hero presentation: "+id)
        };
        public void Apply(Material material)
        {material.SetFloat("_Wind",Wind);material.SetFloat("_HairClump",Clump);material.SetFloat("_HairFrizz",Frizz);material.SetFloat("_MicroStrength",Micro);material.SetFloat("_Rim",Rim);material.SetFloat("_Scatter",Scatter);}
        public Mesh SelectHair(Mesh source)
        {
            int available=source.triangles.Length/6;if(HairCards>=available)return source;
            var mesh=UnityEngine.Object.Instantiate(source);mesh.name="Original distributed hair cards "+HairCards;var original=source.triangles;var triangles=new int[HairCards*6];
            for(int card=0;card<HairCards;card++)Array.Copy(original,Math.Min(available-1,(int)((card+.5f)*available/HairCards))*6,triangles,card*6,6);
            mesh.triangles=triangles;return mesh;
        }
    }
}
