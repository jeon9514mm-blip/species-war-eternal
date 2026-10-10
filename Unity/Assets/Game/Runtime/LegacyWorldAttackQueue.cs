using System;
using System.Linq;
using Newtonsoft.Json.Linq;
using UnityEngine;
using L=Eternal.UnityMigration.LegacyFeatureCatalog;

namespace Eternal.UnityMigration
{
    // Original bounded FIFO attack queues. Imported forces are resolved against
    // actual defending squads; power numbers never decide a capture by themselves.
    public static class LegacyWorldAttackQueue
    {
        public static bool Enqueue(LegacyWorldWar world,Vector2Int target,JObject force)
        {
            string id=(string)force["force_id"];if(!LegacyWorldWar.Bounds(target)||string.IsNullOrEmpty(id))return false;
            var queues=(JObject)world.Conflict["attack_queues"];var queue=L.Array(queues[LegacyWorldWar.Key(target)]);
            if(queue.Count>=8||queue.Any(f=>(string)f["force_id"]==id))return false;
            queue.Add(force.DeepClone());queues[LegacyWorldWar.Key(target)]=queue;return true;
        }
        public static JObject Process(LegacyWorldWar world,Vector2Int target,JObject trustedLocal,long now)
        {
            string key=LegacyWorldWar.Key(target);var queues=(JObject)world.Conflict["attack_queues"];var queue=L.Array(queues[key]);
            if(queue.Count==0||world.Phase(now)!="active")return new JObject{{"error","처리할 공격이 없거나 시즌 정산 중입니다."}};
            var raw=L.Object(queue[0]);queue.RemoveAt(0);if(queue.Count==0)queues.Remove(key);else queues[key]=queue;
            bool local=(string)raw["force_id"]=="player_local";var force=local?trustedLocal:raw;
            string faction=(string)force["faction"];if(!new[]{"aurelia","noxfera"}.Contains(faction)||!world.CanAttack(faction,target))return new JObject{{"error","공격 진영·영토 조건이 변경되었습니다."}};
            var attackers=Alive(L.Array(force["squad"]));if(attackers.Count==0)return new JObject{{"error","움직일 수 있는 공격 부대가 없습니다."}};
            var map=(JObject)world.Conflict["tile_garrisons"];var defenders=L.Array(map[key]);string owner=world.Owner(target);
            if(defenders.Count==0)
            {
                var legacy=L.Array(world.State["garrisons"]?[key]);int count=world.Kind(target)=="capital"?5:world.Kind(target)=="citadel"?4:world.Kind(target)=="fort"?3:new[]{"mine","forest_resource","ruins"}.Contains(world.Kind(target))?2:1;
                if(legacy.Count>0)defenders.Add(new JObject{{"force_id","legacy_"+key},{"faction",owner},{"squad",legacy.DeepClone()}});
                else for(int i=0;i<Math.Min(count,world.Capacity(target));i++)defenders.Add(new JObject{{"force_id","npc_"+key+"_"+i},{"faction",owner},{"is_npc",true},{"squad",LegacyWarBattle.Garrison(owner,target+new Vector2Int(i,i*2),world.Kind(target),(int)(Math.Max(700,L.N(force["power"],700,100000000))*(.82+i*.08)))}});
            }
            var battles=new JArray();int defeated=0;
            while(defenders.Count>0&&LegacyWarBattle.Hp(attackers)>0)
            {
                var defender=L.Object(defenders[0]);var result=LegacyWarBattle.Resolve(attackers,L.Array(defender["squad"]),(int)L.N(force["fatigue"],0,100),world.Defense(target,owner),(string)force["stance"]??"balanced",(int)(world.Revision%1000000)+target.x*97+target.y*13+battles.Count*97+1);
                battles.Add(result);attackers=Alive(L.Array(result["attacker_units"]));
                if(L.Flag(result["victory"])){defenders.RemoveAt(0);defeated++;}
                else{defender["squad"]=result["defender_units"].DeepClone();break;}
            }
            bool victory=defenders.Count==0;
            if(victory)
            {
                world.Tile(target)["owner"]=faction;map.Remove(key);((JObject)world.State["garrisons"]).Remove(key);
                var winner=(JObject)force.DeepClone();winner["squad"]=attackers.DeepClone();world.Register(target,winner);
                var scores=(JObject)world.Season["faction_scores"];int points=world.Kind(target)=="citadel"?120:world.Kind(target)=="fort"?60:world.Kind(target)=="ruins"?30:new[]{"mine","forest_resource"}.Contains(world.Kind(target))?24:10;scores[faction]=L.N(scores[faction])+points;world.Season["captures"]=L.N(world.Season["captures"])+1;
                if(local){world.ArriveOwn(target);world.State["captured_count"]=L.N(world.State["captured_count"])+1;var contribution=(JObject)world.Season["player_contribution"];contribution["local_player"]=L.N(contribution["local_player"])+points;world.Conflict["total_captures"]=L.N(world.Conflict["total_captures"])+1;}
            }
            else{map[key]=defenders;world.ScoreDefense(owner,now);}
            if(local)
            {
                var wounds=(JObject)world.State["army_wounds"];foreach(var unit in L.Array(trustedLocal["squad"]).OfType<JObject>()){var survivor=attackers.OfType<JObject>().FirstOrDefault(u=>(string)u["id"]==(string)unit["id"]);wounds[(string)unit["id"]]=survivor==null?0:L.N(survivor["hp"])/(double)Math.Max(1,L.N(survivor["max_hp"]));}
                world.Fatigue+=victory?12+defeated*3:20+defeated*4;world.Conflict["contribution_points"]=L.N(world.Conflict["contribution_points"])+defeated*25+(victory?100:0);
            }
            var report=new JObject{{"captured",victory},{"victory",victory},{"target",new JArray(target.x,target.y)},{"timestamp",now},{"attacker_force_id",force["force_id"]},{"attacker_name",force["player_name"]??"공격대"},{"defeated_forces",defeated},{"remaining_defenders",defenders.Count},{"attacker_units",attackers},{"battle_summaries",battles},{"fatigue_after",world.Fatigue}};
            var history=L.Array(world.Conflict["campaign_reports"]);history.Insert(0,report.DeepClone());while(history.Count>20)history.RemoveAt(history.Count-1);world.Conflict["campaign_reports"]=history;world.RevisionUp();return report;
        }
        static JArray Alive(JArray squad)=>new(squad.OfType<JObject>().Where(u=>L.N(u["hp"])>0&&L.N(u["max_hp"])>0).Take(10).Select(u=>u.DeepClone()));
    }
}
