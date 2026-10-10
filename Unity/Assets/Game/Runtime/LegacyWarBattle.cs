using System;
using System.Linq;
using Newtonsoft.Json.Linq;
using UnityEngine;
using L=Eternal.UnityMigration.LegacyFeatureCatalog;

namespace Eternal.UnityMigration
{
    public static class LegacyWarBattle
    {
        static int Round(double n)=>Math.Max(0,(int)Math.Round(n,MidpointRounding.AwayFromZero));
        public static JArray Clone(JArray raw)=>new(raw.OfType<JObject>().Take(10).Select(u=>
        {var v=(JObject)u.DeepClone();int max=(int)L.N(v["max_hp"],100,1000000000);v["max_hp"]=Math.Max(1,max);v["hp"]=L.N(v["hp"],max,max);v["attack"]=Math.Max(1,L.N(v["attack"],20));v["defense"]=L.N(v["defense"],5);v["role"]=(string)v["role"]??"딜러";v["row"]=(string)v["row"]??"중열";v["name"]=(string)v["name"]??"병사";return v;}));
        public static long Hp(JArray squad)=>squad.OfType<JObject>().Sum(u=>L.N(u["hp"]));
        static JObject Target(JObject actor,JArray enemy)
        {var alive=enemy.OfType<JObject>().Where(u=>L.N(u["hp"])>0).ToArray();if((string)actor["role"]=="암살자"){var back=alive.FirstOrDefault(u=>(string)u["row"]=="후열"||(string)u["role"]=="서포터");if(back!=null)return back;}return alive.FirstOrDefault(u=>(string)u["role"]=="탱커")??alive.OrderBy(u=>Array.IndexOf(new[]{"전열","중열","후열"},(string)u["row"])).FirstOrDefault();}
        public static JObject Resolve(JArray attackers,JArray defenders,int fatigue,double defense,string stance,int seed=1,Func<double> roll=null)
        {
            var a=Clone(attackers);var d=Clone(defenders);var rng=new System.Random(Math.Max(1,seed));roll??=rng.NextDouble;
            foreach(var u in a.OfType<JObject>()){double ratio=L.N(u["hp"])/(double)Math.Max(1,L.N(u["max_hp"]));u["_base_attack"]=u["attack"];u["_base_defense"]=u["defense"];u["_base_max_hp"]=u["max_hp"];double f=1-Math.Min(.30,Math.Clamp(fatigue,0,100)*.003);u["attack"]=Math.Max(1,Round(L.N(u["attack"])*f));u["max_hp"]=Math.Max(1,Round(L.N(u["max_hp"])*f));u["hp"]=(int)Math.Ceiling(L.N(u["max_hp"])*ratio);u["attack"]=Math.Max(1,Round(L.N(u["attack"])*(stance=="assault"?1.15:stance=="guard"?.9:1)));u["defense"]=Round(L.N(u["defense"])*(stance=="assault"?.85:stance=="guard"?1.2:1));}
            foreach(var u in d.OfType<JObject>()){double ratio=L.N(u["hp"])/(double)Math.Max(1,L.N(u["max_hp"]));u["_base_defense"]=u["defense"];u["_base_max_hp"]=u["max_hp"];u["defense"]=Round(L.N(u["defense"])*Math.Clamp(defense,.1,3));u["max_hp"]=Math.Max(1,Round(L.N(u["max_hp"])*Math.Max(.1,1+(defense-1)*.45)));u["hp"]=(int)Math.Ceiling(L.N(u["max_hp"])*ratio);}
            var logs=new JArray();var timeline=new JArray();long dealt=0,taken=0;int rounds=0;
            long Act(JArray side,JArray opposite,string label)
            {
                long damage=0;foreach(var u in side.OfType<JObject>().Where(u=>L.N(u["hp"])>0))
                {
                    if(Hp(opposite)<=0)break;
                    if((string)u["role"]=="서포터")
                    {var low=side.OfType<JObject>().Where(t=>L.N(t["hp"])>0).OrderBy(t=>L.N(t["hp"])/(double)Math.Max(1,L.N(t["max_hp"]))).FirstOrDefault();if(low!=null&&L.N(low["hp"])<L.N(low["max_hp"])){long heal=Math.Min(Math.Max(1,Round(L.N(u["attack"])*.72)),L.N(low["max_hp"])-L.N(low["hp"]));low["hp"]=L.N(low["hp"])+heal;if(logs.Count<16)logs.Add(label+" "+u["name"]+" → "+low["name"]+" 회복 +"+heal);continue;}}
                    var target=Target(u,opposite);if(target==null)break;int hit=Math.Max(1,Round(L.N(u["attack"])*(.9+Math.Clamp(roll(),0,1)*.2)-L.N(target["defense"])*.58));if((string)u["role"]=="컨트롤러")hit=Round(hit*.92);else if((string)u["role"]=="암살자"&&(string)target["row"]=="후열")hit=Round(hit*1.18);hit=Math.Min(hit,(int)L.N(target["hp"]));target["hp"]=L.N(target["hp"])-hit;damage+=hit;if(logs.Count<16)logs.Add(label+" "+u["name"]+" → "+target["name"]+" "+hit+" 피해"+(L.N(target["hp"])==0?" · 격파":""));
                }return damage;
            }
            for(int r=1;r<=30;r++){rounds=r;long ah=Act(a,d,"공격"),dh=Hp(d)>0?Act(d,a,"수비"):0;dealt+=ah;taken+=dh;timeline.Add(new JObject{{"round",r},{"attacker_hp",Hp(a)},{"defender_hp",Hp(d)},{"attacker_damage",ah},{"defender_damage",dh}});if(Hp(a)<=0||Hp(d)<=0)break;}
            bool victory=Hp(a)>0&&(Hp(d)==0||rounds>=30&&Hp(a)>Hp(d));
            void Restore(JArray squad){foreach(var u in squad.OfType<JObject>()){double ratio=L.N(u["hp"])/(double)Math.Max(1,L.N(u["max_hp"]));foreach(string key in new[]{"max_hp","attack","defense"})if(u["_base_"+key]!=null){u[key]=u["_base_"+key].DeepClone();u.Remove("_base_"+key);}u["hp"]=Math.Min(L.N(u["max_hp"]),(long)Math.Ceiling(L.N(u["max_hp"])*ratio));}}
            Restore(a);Restore(d);return new JObject{{"victory",victory},{"rounds",rounds},{"attacker_alive",a.OfType<JObject>().Count(u=>L.N(u["hp"])>0)},{"defender_alive",d.OfType<JObject>().Count(u=>L.N(u["hp"])>0)},{"attacker_hp",Hp(a)},{"defender_hp",Hp(d)},{"attacker_damage",dealt},{"defender_damage",taken},{"attacker_units",a},{"defender_units",d},{"logs",logs},{"timeline",timeline},{"stance",stance}};
        }
        // Native deterministic generator. Original saved units are reused verbatim;
        // Unity's RNG sequence differs from Godot's PCG for newly seeded NPCs.
        public static JArray Garrison(string faction,Vector2Int tile,string type,int power)
        {
            var rng=new System.Random(Math.Max(1,(tile.x+11)*1009+(tile.y+23)*917+(faction=="aurelia"?1:2)*7919));string[] roles={"탱커","딜러","딜러","서포터","컨트롤러","딜러","암살자","딜러","서포터","딜러"},rows={"전열","전열","중열","후열","중열","중열","후열","후열","후열","중열"};var result=new JArray();double unit=Math.Max(55,Math.Max(600,power)/20d),landmark=type=="fort"?1.12:type=="citadel"?1.18:type=="capital"?1.30:1;
            for(int i=0;i<10;i++){string role=roles[i];double h=role=="탱커"?1.45:role=="서포터"?1.05:role=="암살자"?.9:1,a=role=="탱커"?.75:role=="서포터"?.82:role=="암살자"?1.25:1;int hp=(int)((250+unit*2.8)*h*landmark*(.95+rng.NextDouble()*.1)),attack=(int)((18+unit*.34)*a*landmark*(.95+rng.NextDouble()*.1));result.Add(new JObject{{"id","garrison_"+i},{"name",(faction=="aurelia"?"아우렐리아":"녹스페라")+" 수비대 "+(i+1).ToString("D2")},{"role",role},{"row",rows[i]},{"max_hp",hp},{"hp",hp},{"attack",attack},{"defense",(int)(5+unit*.055)+(role=="탱커"?12:role=="서포터"?4:0)}});}return result;
        }
    }
}
