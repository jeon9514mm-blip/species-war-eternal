using System;
using System.Collections.Generic;
using System.Linq;
using Newtonsoft.Json.Linq;
using UnityEngine;
using L=Eternal.UnityMigration.LegacyFeatureCatalog;

namespace Eternal.UnityMigration
{
    public sealed class LegacyWorldWar
    {
        public readonly JObject State,March,Conflict,Season,Authority;
        public string Faction=>(string)State["faction"];
        public string Enemy=>Faction=="aurelia"?"noxfera":"aurelia";
        public Vector2Int Army=>Cell(State["army_position"]);
        public long Rations {get=>L.N(State["rations"]);set=>State["rations"]=Math.Clamp(value,0,1000000000);}
        public int Fatigue {get=>(int)L.N(State["army_fatigue"],0,100);set=>State["army_fatigue"]=Math.Clamp(value,0,100);}
        public long Revision=>L.N(Authority["last_revision"]);
        public static string Key(Vector2Int p)=>p.x+":"+p.y;
        public static Vector2Int Cell(JToken pair)=>pair is JArray a&&a.Count>=2?new Vector2Int((int)GameStateCommands.Integer(a[0],-1,-1,39),(int)GameStateCommands.Integer(a[1],-1,-1,39)):new Vector2Int(-1,-1);
        public static bool Bounds(Vector2Int p)=>p.x>=0&&p.x<40&&p.y>=0&&p.y<40;
        public static Vector2Int Capital(string faction)=>faction=="aurelia"?new(1,10):new(18,10);
        static JObject Map(JObject root,string key){if(root[key] is JObject map)return map;var next=new JObject();root[key]=next;return next;}
        public LegacyWorldWar(JObject root,string faction,long now)
        {
            var original=L.Object(root["faction_war"]);State=(JObject)L.Data["initial_worlds"][faction].DeepClone();
            if(L.Object(original["cells"]).Count>0)
            {
                foreach(var field in original.Properties().Where(p=>p.Name!="cells"))State[field.Name]=field.Value.DeepClone();
                foreach(var tile in L.Object(State["cells"]).Properties())if(original["cells"]?[tile.Name] is JObject saved)
                {var item=(JObject)tile.Value;string owner=(string)saved["owner"],type=(string)saved["type"];if(new[]{"aurelia","noxfera","neutral"}.Contains(owner))item["owner"]=owner;if(new[]{"plain","forest","hills","mine","forest_resource","ruins","fort","citadel","capital"}.Contains(type))item["type"]=type;item["level"]=L.N(saved["level"],1,100);item["guard_level"]=L.N(saved["guard_level"],0,5);}
            }
            else State["last_logistics_unix"]=now;
            State["faction"]=faction;State["initialized"]=true;State["world_version"]=5;Rations=Rations;Fatigue=Fatigue;
            foreach(string f in new[]{"aurelia","noxfera"})foreach(var p in Tiles().Where(p=>Distance(p,Capital(f))<=2))Tile(p)["owner"]=f;
            if(Owner(Army)!=Faction)State["army_position"]=new JArray(faction=="aurelia"?2:17,10);
            State["battle_stance"]=new[]{"balanced","assault","guard"}.Contains((string)State["battle_stance"])?State["battle_stance"]:"balanced";
            root["faction_war"]=State;March=Map(root,"faction_march");Conflict=Map(root,"faction_conflict");Season=Map(root,"world_season");Authority=Map(root,"world_authority");
            Map(State,"garrisons");Map(State,"army_wounds");Map(Conflict,"tile_garrisons");Map(Conflict,"rallies");Map(Conflict,"attack_queues");Map(Conflict,"support_awards");Conflict["conflict_version"]=2;
            SanitizeMarch();EnsureSeason(now);
        }
        void SanitizeMarch()
        {
            if(!L.Flag(March["active"]))return;var path=L.Array(March["path"]);string action=(string)March["action"];
            bool valid=(string)March["faction"]==Faction&&path.Count>=2&&path.Count<=1600&&L.F(March["duration_seconds"])>0&&L.F(March["duration_seconds"])<=86400&&new[]{"move","support","capture_neutral","attack_enemy","forced_retreat"}.Contains(action)&&Cell(path[0])==Cell(March["origin"])&&Cell(path[path.Count-1])==Cell(March["target"]);
            for(int i=0;i<path.Count;i++)valid&=Bounds(Cell(path[i]))&&(i==0||action=="forced_retreat"||Distance(Cell(path[i]),Cell(path[i-1]))==1);
            if(!valid){March["active"]=false;March["last_result"]="손상된 행군 기록 중단";return;}
            if(L.F(March["authority_started_unix"])<=0)March["authority_started_unix"]=L.N(March["last_system_unix"],0,long.MaxValue)-L.F(March["elapsed_seconds"]);
        }
        public IEnumerable<Vector2Int> Tiles(){for(int y=0;y<40;y++)for(int x=0;x<40;x++)yield return new(x,y);}
        public JObject Tile(Vector2Int p)=>Bounds(p)?L.Object(State["cells"]?[Key(p)]):new JObject();
        public string Owner(Vector2Int p)=>(string)Tile(p)["owner"]??"";
        public string Kind(Vector2Int p)=>(string)Tile(p)["type"]??"";
        public static int Distance(Vector2Int a,Vector2Int b)=>Math.Abs(a.x-b.x)+Math.Abs(a.y-b.y);
        public IEnumerable<Vector2Int> Neighbors(Vector2Int p)=>new[]{p+Vector2Int.left,p+Vector2Int.right,p+new Vector2Int(0,-1),p+new Vector2Int(0,1)}.Where(Bounds);
        public string Sanctuary(Vector2Int p)=>Distance(p,Capital("aurelia"))<=2?"aurelia":Distance(p,Capital("noxfera"))<=2?"noxfera":"neutral";
        public int Tier(string faction)
        {int own=Tiles().Count(p=>Owner(p)==faction),enemy=Tiles().Count(p=>Owner(p)==(faction=="aurelia"?"noxfera":"aurelia"));double ratio=own/(double)Math.Max(1,enemy);return ratio<=.45?3:ratio<=.65?2:ratio<=.85?1:0;}
        public bool CanAttack(string faction,Vector2Int p)
        {string enemy=faction=="aurelia"?"noxfera":"aurelia";int tier=Tier(enemy);return Bounds(p)&&Owner(p)==enemy&&Sanctuary(p)!=enemy&&!(tier>=2&&Distance(p,Capital(enemy))<=(tier==2?4:5));}
        public HashSet<string> Supply(string faction)
        {
            var visited=new HashSet<string>();var queue=new Queue<Vector2Int>();var start=Capital(faction);if(Owner(start)!=faction)return visited;queue.Enqueue(start);visited.Add(Key(start));
            while(queue.Count>0)foreach(var p in Neighbors(queue.Dequeue()))if(Owner(p)==faction&&visited.Add(Key(p)))queue.Enqueue(p);return visited;
        }
        public List<Vector2Int> Path(Vector2Int target)
        {
            if(!Bounds(target))return new();if(target==Army)return new(){Army};
            if(Owner(target)!=Faction&&Owner(target)!="neutral"&&!CanAttack(Faction,target)||Sanctuary(target)!="neutral"&&Sanctuary(target)!=Faction)return new();
            var queue=new Queue<Vector2Int>();var from=new Dictionary<Vector2Int,Vector2Int>{{Army,Army}};queue.Enqueue(Army);
            while(queue.Count>0)
            {var p=queue.Dequeue();foreach(var n in Neighbors(p)){if(from.ContainsKey(n)||n!=target&&Owner(n)!=Faction)continue;from[n]=p;if(n==target){var cursor=n;var path=new List<Vector2Int>{cursor};while(cursor!=Army){cursor=from[cursor];path.Add(cursor);}path.Reverse();return path;}queue.Enqueue(n);}}
            return new();
        }
        public JObject Quote(Vector2Int target,string requested="")
        {
            if(L.Flag(March["active"]))return new();var path=Path(target);if(path.Count<2)return new();
            string action=Owner(target)==Faction?(requested=="support"?"support":"move"):Owner(target)=="neutral"?"capture_neutral":"attack_enemy";
            int distance=path.Count-1,tier=Tier(Faction);double speed=new[]{1,1.1,1.2,1.3}[tier],mult=new[]{1,.9,.8,.7}[tier];
            return new JObject{{"path",new JArray(path.Select(p=>new JArray(p.x,p.y)))},{"target",new JArray(target.x,target.y)},{"origin",new JArray(Army.x,Army.y)},{"action",action},{"distance",distance},{"duration_seconds",Math.Max(1,distance*4/speed)},{"ration_cost",Math.Max(1,(int)Math.Ceiling(distance*8*mult))}};
        }
        public string Check(JObject quote,JArray squad,long now)
        {
            if(quote.Count==0)return "행군 경로 없음";var target=Cell(quote["target"]);string action=(string)quote["action"];bool conquering=action=="attack_enemy"||action=="capture_neutral";
            if(conquering&&Phase(now)!="active")return "시즌 정산 중";
            if(conquering&&(action=="attack_enemy"||L.N(Tile(target)["guard_level"])>0)&&Fatigue>=85)return "피로 한도";
            if(conquering&&!squad.OfType<JObject>().Any(u=>L.N(u["hp"])>0))return "부상 회복 필요";
            if(conquering&&!Supply(Faction).Contains(Key(Army)))return "보급 단절";
            if(Rations<L.N(quote["ration_cost"]))return "군량 부족";return "";
        }
        public void Begin(JObject quote,long now,string context="")
        {Rations-=L.N(quote["ration_cost"]);foreach(var p in quote.Properties())March[p.Name]=p.Value.DeepClone();March["active"]=true;March["faction"]=Faction;March["context_id"]=context;March["elapsed_seconds"]=0;March["last_system_unix"]=now;March["authority_started_unix"]=now;March["authority_end_unix"]=now+L.F(quote["duration_seconds"]);March["last_authority_unix"]=now;March["last_result"]="행군 시작";RemoveForce("player_local");}
        public void RevisionUp()=>Authority["last_revision"]=Revision+1;
        public bool LogisticsDue(long now)=>now-L.N(State["last_logistics_unix"],now,long.MaxValue)>=60;
        public JObject AdvanceLogistics(long now)
        {
            long last=L.N(State["last_logistics_unix"],0,long.MaxValue);if(last<=0){State["last_logistics_unix"]=now;return new();}if(now<=last)return new();long productionEnd=Math.Min(now,L.N(Season["active_end_unix"],now,long.MaxValue));long seconds=Math.Min(8*3600,Math.Max(0,productionEnd-last));State["last_logistics_unix"]=now;
            var supplied=Supply(Faction);double food=2,honor=0;
            foreach(var tile in Tiles().Where(p=>Owner(p)==Faction)){double efficiency=supplied.Contains(Key(tile))?1:.25;string kind=Kind(tile);if(kind=="mine")food+=5*efficiency;if(kind=="forest_resource")food+=8*efficiency;if(kind=="ruins")honor+=efficiency;}
            double mult=new[]{1,1.05,1.1,1.18}[Tier(Faction)],f=L.F(State["ration_fraction"])+food*mult*seconds/60,h=L.F(State["honor_fraction"])+honor*mult*seconds/60;long r=(long)Math.Floor(f),a=(long)Math.Floor(h);
            State["ration_fraction"]=f-r;State["honor_fraction"]=h-a;Rations+=r;State["campaign_honor"]=Math.Min(1000000000,L.N(State["campaign_honor"])+a);var report=new JObject{{"seconds",seconds},{"rations",r},{"honor",a}};State["last_logistics_report"]=report;return report;
        }
        void EnsureSeason(long now)
        {
            if(L.N(Season["start_unix"],0,long.MaxValue)>0){long start=L.N(Season["start_unix"],0,long.MaxValue);Season["active_end_unix"]=Math.Max(start,L.N(Season["active_end_unix"],start+28*86400,long.MaxValue));Season["settlement_end_unix"]=Math.Max(L.N(Season["active_end_unix"],0,long.MaxValue),L.N(Season["settlement_end_unix"],start+30*86400,long.MaxValue));Phase(now);return;}
            Season["season_version"]=2;Season["season_number"]=Math.Max(1,L.N(Season["season_number"],1));Season["season_id"]="S"+L.N(Season["season_number"],1).ToString("D3");Season["phase"]="active";Season["start_unix"]=now;Season["active_end_unix"]=now+28*86400;Season["settlement_end_unix"]=now+30*86400;Season["last_observed_unix"]=now;Season["faction_scores"]=new JObject{{"aurelia",0},{"noxfera",0}};Season["player_contribution"]=new JObject();Season["reward_claims"]=new JObject();Season["captures"]=0;Season["defenses"]=0;
        }
        public string Phase(long now)
        {long watermark=Math.Max(now,L.N(Season["last_observed_unix"],0,long.MaxValue));if((string)Season["phase"]=="settlement")watermark=Math.Max(watermark,L.N(Season["active_end_unix"],0,long.MaxValue));if((string)Season["phase"]=="ended")watermark=Math.Max(watermark,L.N(Season["settlement_end_unix"],0,long.MaxValue));Season["last_observed_unix"]=watermark;string phase=watermark<L.N(Season["active_end_unix"],0,long.MaxValue)?"active":watermark<L.N(Season["settlement_end_unix"],0,long.MaxValue)?"settlement":"ended";Season["phase"]=phase;return phase;}
        public void ScoreCapture(Vector2Int p,bool enemy,string player,long now)
        {if(Phase(now)!="active")return;int score=Kind(p)=="capital"?0:Kind(p)=="citadel"?60:Kind(p)=="fort"?30:Kind(p)=="ruins"?15:new[]{"mine","forest_resource"}.Contains(Kind(p))?12:5;if(!enemy)score=Math.Max(1,(int)Math.Ceiling(score*.5));Map(Season,"faction_scores")[Faction]=L.N(Season["faction_scores"]?[Faction])+score;Map(Season,"player_contribution")[player]=L.N(Season["player_contribution"]?[player])+score;Season["captures"]=L.N(Season["captures"])+1;}
        public void ScoreDefense(string faction,long now)
        {if(Phase(now)!="active")return;var scores=Map(Season,"faction_scores");scores[faction]=L.N(scores[faction])+5;Season["defenses"]=L.N(Season["defenses"])+1;}
        public JObject SeasonReward(string player,long now)
        {string phase=Phase(now);long points=L.N(Season["player_contribution"]?[player]);long own=L.N(Season["faction_scores"]?[Faction]),enemy=L.N(Season["faction_scores"]?[Enemy]);return new JObject{{"contribution",points},{"claimable",points>0&&phase!="active"&&!L.Object(Season["reward_claims"]).ContainsKey(player)},{"rations",200+Math.Min(800,points*2)},{"honor",50+Math.Min(500,points)+(own>enemy?100:own==enemy?50:0)}};}
        public void RemoveForce(string id)
        {var map=Map(Conflict,"tile_garrisons");foreach(var p in map.Properties().ToArray()){var remaining=new JArray(L.Array(p.Value).OfType<JObject>().Where(f=>(string)f["force_id"]!=id).Select(f=>f.DeepClone()));if(remaining.Count==0)p.Remove();else p.Value=remaining;}}
        public int Capacity(Vector2Int p)=>Kind(p)=="capital"?8:Kind(p)=="citadel"?6:Kind(p)=="fort"?5:new[]{"mine","forest_resource","ruins"}.Contains(Kind(p))?3:2;
        public bool Register(Vector2Int p,JObject force)
        {
            if(Owner(p)!=(string)force["faction"]||!Supply(Owner(p)).Contains(Key(p))||!L.Array(force["squad"]).OfType<JObject>().Any(u=>L.N(u["hp"])>0))return false;
            var map=Map(Conflict,"tile_garrisons");var list=L.Array(map[Key(p)]);string id=(string)force["force_id"];
            var current=list.OfType<JObject>().FirstOrDefault(f=>(string)f["force_id"]==id);if(current!=null){current.Replace(force.DeepClone());return true;}
            if(list.Count>=Capacity(p))return false;RemoveForce(id);list=L.Array(map[Key(p)]);list.Add(force.DeepClone());map[Key(p)]=list;
            var awards=Map(Conflict,"support_awards");string key=id+"|"+Key(p);if(!awards.ContainsKey(key)){awards[key]=true;Conflict["total_supports"]=L.N(Conflict["total_supports"])+1;Conflict["contribution_points"]=L.N(Conflict["contribution_points"])+5;}return true;
        }
        public void ArriveOwn(Vector2Int p)
        {State["army_position"]=new JArray(p.x,p.y);if(Kind(p)=="capital"){Fatigue-=35;State["army_wounds"]=new JObject();}}
        public double Defense(Vector2Int p,string owner)
        {double bonus=Kind(p)=="fort"?1.18:Kind(p)=="citadel"?1.12:new[]{"mine","forest_resource","ruins"}.Contains(Kind(p))?1.05:1;bool fort=Neighbors(p).Any(n=>Owner(n)==owner&&Kind(n)=="fort");return bonus*(fort?1.06:1)*(Supply(owner).Contains(Key(p))?1:.82)*new[]{1,1.1,1.18,1.28}[Tier(owner)];}
    }
}
