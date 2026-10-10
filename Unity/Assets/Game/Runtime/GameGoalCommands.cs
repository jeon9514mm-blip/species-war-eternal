using System;
using System.Linq;
using Newtonsoft.Json.Linq;
using L=Eternal.UnityMigration.LegacyFeatureCatalog;

namespace Eternal.UnityMigration
{
    public sealed partial class GameStateCommands
    {
        static readonly string[] GoalEvents={"hunt_packs","daily_clear","tower_clear","abyss_clear","raid_clear"};
        static readonly string[] GoalScopes={"guide","daily","weekly","achievement"};
        static JArray Definitions(string scope)=>L.Array(L.Data["goals"]?[scope]);
        JObject GoalState(JObject state,long now)
        {
            var raw=L.Object(state["long_term_goals"]);var result=new JObject{{"schema",1},{"factions",new JObject()}};
            JObject Counts(JToken source,string[] names)=>new(names.Select(k=>new JProperty(k,L.N(source?[k]))));
            JObject Flags(JToken source,string scope)=>new(Definitions(scope).OfType<JObject>().Where(e=>L.Flag(source?[(string)e["id"]])).Select(e=>new JProperty((string)e["id"],true)));
            foreach(string scope in new[]{"daily","weekly"})
            {
                var source=L.Object(raw[scope]);string old=scope=="daily"?L.ValidDay(source["key"]):L.ValidWeek(source["key"]),current=scope=="daily"?L.Day(now):L.Week(now);
                bool reset=old.Length==0||(scope=="daily"?string.CompareOrdinal(current,old)>0:long.Parse(current)>long.Parse(old));
                result[scope]=new JObject{{"key",reset?current:old},{"counts",reset?Counts(null,GoalEvents):Counts(source["counts"],GoalEvents)},{"claimed",reset?new JObject():Flags(source["claimed"],scope)}};
            }
            foreach(string faction in new[]{"aurelia","noxfera"})
            {
                var source=L.Object(raw["factions"]?[faction]);var seen=new JObject();
                foreach(string id in catalog.HeroIds.Where(id=>heroFactions[id]==faction&&L.Flag(source["discovered"]?[id])))seen[id]=true;
                var best=Counts(source["best"],new[]{"stage","hero_level","tower_best"});best["stage"]=L.N(best["stage"],0,10000);best["hero_level"]=L.N(best["hero_level"],0,100);best["tower_best"]=L.N(best["tower_best"],0,9999);
                var achievements=Flags(source["achievements"],"achievement");string title=(string)source["title"]??"";
                if(L.Data["definitions"]?["goals"]?["TITLES"]?[title]==null||!L.Flag(achievements[title]))title="";
                result["factions"][faction]=new JObject{{"totals",Counts(source["totals"],GoalEvents)},{"best",best},{"guide_claimed",L.N(source["guide_claimed"],0,100)},{"achievements",achievements},{"discovered",seen},{"title",title}};
            }
            string active=(string)state["selected_faction"]??"";
            if(active=="aurelia"||active=="noxfera")
            {
                var bank=(JObject)result["factions"][active];int stage=(int)L.N(state["idle_stage"],1,10000);
                if(L.Flag(state["unity_player_profile"]))stage=Math.Max(stage,1+(int)L.N(state["unity_pack_total"])/5);
                int level=1;
                foreach(string id in catalog.HeroIds.Where(id=>heroFactions[id]==active))
                    if(L.Flag(state["codex_seen"]?[id])||stage>=L.N(catalog.Hero(id)["unlock_stage"],1,10000))
                    {bank["discovered"][id]=true;level=Math.Max(level,(int)L.N(state["hero_progress"]?[id]?["level"],1,100));}
                foreach(var metric in new[]{("stage",stage),("hero_level",level),("tower_best",(int)L.N(state["tower_best_floor"],0,9999))})
                    bank["best"][metric.Item1]=Math.Max(L.N(bank["best"][metric.Item1]),metric.Item2);
            }
            state["long_term_goals"]=result;return result;
        }
        void GoalRecord(JObject state,string eventId,int amount=1,long now=0)
        {
            if(!GoalEvents.Contains(eventId)||amount<1)return;if(now<=0)now=L.Now;
            var goals=GoalState(state,now);string faction=(string)state["selected_faction"];
            if(goals["factions"]?[faction] is not JObject bank)return;
            bank["totals"][eventId]=Math.Min(1000000000,L.N(bank["totals"][eventId])+amount);
            foreach(string scope in new[]{"daily","weekly"})if((string)goals[scope]["key"]==(scope=="daily"?L.Day(now):L.Week(now)))
                goals[scope]["counts"][eventId]=Math.Min(1000000000,L.N(goals[scope]["counts"][eventId])+amount);
        }
        static JObject GoalRow(JObject goals,string faction,string scope,JObject definition)
        {
            var bank=L.Object(goals["factions"]?[faction]);var row=(JObject)definition.DeepClone();string id=(string)row["id"],metric=(string)row["metric"];
            var counts=scope=="daily"||scope=="weekly"?L.Object(goals[scope]?["counts"]):L.Object(bank["totals"]);
            long current=metric=="challenge_clear"?new[]{"daily_clear","tower_clear","abyss_clear","raid_clear"}.Sum(k=>L.N(counts[k])):metric=="guide_claimed"?L.N(bank["guide_claimed"]):metric=="discovered"?L.Object(bank["discovered"]).Count:new[]{"stage","hero_level","tower_best"}.Contains(metric)?L.N(bank["best"]?[metric]):L.N(counts[metric]);
            bool claimed=scope=="guide"?L.N(row["number"])<=L.N(bank["guide_claimed"]):L.Flag(scope=="achievement"?bank["achievements"]?[id]:goals[scope]?["claimed"]?[id]);
            bool unlocked=scope!="guide"||L.N(row["number"])<=L.N(bank["guide_claimed"])+1;
            row["current"]=Math.Min(current,L.N(row["target"]));row["claimed"]=claimed;row["unlocked"]=unlocked;row["complete"]=current>=L.N(row["target"]);row["ready"]=unlocked&&!claimed&&L.Flag(row["complete"]);return row;
        }
        public JArray GoalRows(string scope,long now=0)
        {if(!GoalScopes.Contains(scope))return new JArray();var goals=GoalState(Snapshot(),now>0?now:L.Now);return new JArray(Definitions(scope).OfType<JObject>().Select(e=>GoalRow(goals,Faction,scope,e)));}
        public JObject GoalContext(string scope,long now=0)
        {now=now>0?now:L.Now;return new JObject{{"faction",Faction},{"scope",scope},{"key",scope=="daily"?L.Day(now):scope=="weekly"?L.Week(now):""}};}
        public StateCommandResult ClaimGoal(string scope,string id,JObject expected,long now=0)=>Commit(state=>
        {
            now=now>0?now:L.Now;if(!GoalScopes.Contains(scope)||expected==null||(string)expected["scope"]!=scope||(string)expected["faction"]!=Faction)return StateCommandResult.Fail("목표의 진영·조건이 변경되었습니다.");
            var goals=GoalState(state,now);if((scope=="daily"||scope=="weekly")&&((string)expected["key"]!=(scope=="daily"?L.Day(now):L.Week(now))||(string)goals[scope]["key"]!=(string)expected["key"]))return StateCommandResult.Fail("목표 기간이 변경되었습니다.");
            var definition=Definitions(scope).OfType<JObject>().FirstOrDefault(e=>(string)e["id"]==id);if(definition==null)return StateCommandResult.Fail("목표를 확인하세요.");
            var row=GoalRow(goals,Faction,scope,definition);if(!L.Flag(row["ready"]))return StateCommandResult.Fail("아직 달성하지 않았거나 이미 수령했습니다.");
            var bank=(JObject)goals["factions"][Faction];if(scope=="guide")bank["guide_claimed"]=L.N(bank["guide_claimed"])+1;else if(scope=="achievement")bank["achievements"][id]=true;else goals[scope]["claimed"][id]=true;
            AddCurrency(state,"wallet_gold",L.N(row["gold"]));AddCurrency(state,"wallet_gems",L.N(row["gems"]));return StateCommandResult.Success("목표 수령 · "+row["title"],L.N(row["gold"]));
        });
        public StateCommandResult EquipGoalTitle(string id,string expectedFaction)=>Commit(state=>
        {if(expectedFaction!=Faction)return StateCommandResult.Fail("진영이 변경되었습니다.");var goals=GoalState(state,L.Now);var bank=(JObject)goals["factions"][Faction];if(id.Length>0&&(L.Data["definitions"]["goals"]["TITLES"]?[id]==null||!L.Flag(bank["achievements"]?[id])))return StateCommandResult.Fail("먼저 칭호 업적을 수령하세요.");bank["title"]=id;return StateCommandResult.Success("칭호 저장");});
        public JObject LegacyQuest(string id)
        {
            long raids=L.Object(data["raid_clears"]).Properties().Sum(p=>L.N(p.Value));long stage=Math.Max(L.N(data["idle_stage"],1),1+UnityPacks/5),tower=L.N(data["tower_best_floor"]);
            return id=="stage5"?new JObject{{"title","스테이지 5 도달"},{"current",Math.Min(5,stage)},{"target",5},{"gold",500},{"gems",20}}:id=="raid1"?new JObject{{"title","레이드 1회 클리어"},{"current",Math.Min(1,raids)},{"target",1},{"gold",800},{"gems",30}}:id=="tower5"?new JObject{{"title","무한탑 5층 돌파"},{"current",Math.Min(5,tower)},{"target",5},{"gold",1000},{"gems",40}}:new JObject();
        }
        public StateCommandResult ClaimLegacyQuest(string id)=>Commit(state=>
        {var row=LegacyQuest(id);if(row.Count==0||L.Flag(state["quest_claimed"]?[id])||L.N(row["current"])<L.N(row["target"]))return StateCommandResult.Fail("아직 달성하지 않았거나 이미 수령했습니다.");Map(state,"quest_claimed")[id]=true;state["tracked_quest_id"]=new[]{"stage5","raid1","tower5"}.FirstOrDefault(k=>!L.Flag(state["quest_claimed"]?[k]))??"";AddCurrency(state,"wallet_gold",L.N(row["gold"]));AddCurrency(state,"wallet_gems",L.N(row["gems"]));return StateCommandResult.Success("퀘스트 보상 수령",L.N(row["gold"]));});
    }
}
