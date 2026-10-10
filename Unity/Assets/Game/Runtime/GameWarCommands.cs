using System;
using System.Linq;
using Newtonsoft.Json.Linq;
using UnityEngine;
using L=Eternal.UnityMigration.LegacyFeatureCatalog;

namespace Eternal.UnityMigration
{
    public sealed partial class GameStateCommands
    {
        public bool WarInitialized=>L.Object(data["faction_war"]?["cells"]).Count>0;
        LegacyWorldWar World(JObject draft,long now)=>new(draft,Faction,now);
        JArray WarParty(LegacyWorldWar world)
        {
            var result=new JArray();var ids=DeployedHeroes();for(int i=0;i<ids.Count;i++){string id=ids[i];var profile=CombatProfile(id,i,ids);double ratio=Math.Clamp(L.F(world.State["army_wounds"]?[id],1),0,1);result.Add(new JObject{{"id",id},{"name",catalog.Hero(id)["name"]},{"role",profile["role_group"]},{"row",i<3?"전열":i<7?"중열":"후열"},{"max_hp",profile["max_hp"]},{"hp",(long)Math.Ceiling(L.N(profile["max_hp"])*ratio)},{"attack",profile["attack"]},{"defense",profile["defense"]}});}return result;
        }
        JObject Force(LegacyWorldWar w)=>new(){{"force_id","player_local"},{"player_name","내 원정대"},{"faction",Faction},{"squad",WarParty(w)},{"power",WarPower(w)},{"fatigue",w.Fatigue},{"stance",w.State["battle_stance"]},{"is_npc",false},{"arrived_at",L.Now}};
        int WarPower(LegacyWorldWar w)=>(int)WarParty(w).OfType<JObject>().Sum(u=>L.N(u["hp"])*.12+(L.N(u["attack"])*4+L.N(u["defense"])*2)*L.N(u["hp"])/(double)Math.Max(1,L.N(u["max_hp"])));
        public StateCommandResult InitializeWar()=>Commit(state=>
        {if(Faction!="aurelia"&&Faction!="noxfera")return StateCommandResult.Fail("진영을 먼저 선택하세요.");var w=World(state,L.Now);w.Rations+=L.N(state["unity_pending_rations"]);state["unity_pending_rations"]=0;return StateCommandResult.Success("진영전 기록 연결");});
        public JObject WarView(long now=0)
        {now=now>0?now:L.Now;var draft=Snapshot();var w=World(draft,now);return new JObject{{"world",w.State},{"march",w.March},{"conflict",w.Conflict},{"season",w.Season},{"revision",w.Revision},{"supply",new JArray(w.Supply(Faction))},{"reward",w.SeasonReward("local_player",now)}};}
        public JObject WarQuote(int x,int y,string requested="",long now=0)
        {now=now>0?now:L.Now;var w=World(Snapshot(),now);var p=new Vector2Int(x,y);var quote=w.Quote(p,requested);quote["error"]=w.Check(quote,WarParty(w),now);quote["revision"]=w.Revision;quote["owner"]=w.Owner(p);quote["kind"]=w.Kind(p);quote["guard_level"]=L.N(w.Tile(p)["guard_level"]);return quote;}
        StateCommandResult WarCommandDraft(JObject state,string action,int x,int y,string context,long expectedRevision,long now)
        {
            now=now>0?now:L.Now;if(!WarInitialized)return StateCommandResult.Fail("진영전 기록을 먼저 연결하세요.");var w=World(state,now);if(expectedRevision>=0&&expectedRevision!=w.Revision)return StateCommandResult.Fail("월드 기록이 변경되었습니다. 다시 확인하세요.");w.AdvanceLogistics(now);var target=new Vector2Int(x,y);var force=Force(w);string error="";
            if(action=="set_stance")
            {if(L.Flag(w.March["active"])||!new[]{"balanced","assault","guard"}.Contains(context))error="행군 중이거나 전술 정보가 잘못되었습니다.";else w.State["battle_stance"]=context;}
            else if(action=="march"||action=="support"||action=="rally_march")
            {
                var quote=w.Quote(target,action=="support"?"support":"");error=w.Check(quote,WarParty(w),now);
                if(action=="support"&&(w.Owner(target)!=Faction||!w.Supply(Faction).Contains(LegacyWorldWar.Key(target))||L.Array(w.Conflict["tile_garrisons"]?[LegacyWorldWar.Key(target)]).Count>=w.Capacity(target)))error="지원 위치·보급·주둔 한도를 확인하세요.";
                if(action=="rally_march"&&(w.Conflict["rallies"]?[context] is not JObject rally||LegacyWorldWar.Cell(rally["target"])!=target||(string)rally["faction"]!=Faction))error="집결 정보가 변경되었습니다.";
                if(error.Length==0)w.Begin(quote,now,action=="rally_march"?context:"");
            }
            else if(action=="cancel_march")
            {if(!L.Flag(w.March["active"]))error="취소할 행군 없음";else {w.Rations+=(long)Math.Round(L.N(w.March["ration_cost"])*.5,MidpointRounding.AwayFromZero);w.March["active"]=false;w.March["last_result"]="행군 취소 · 군량 50% 환급";Map(w.Conflict,"rallies").Remove((string)w.March["context_id"]??"");w.Register(w.Army,force);}}
            else if(action=="forced_retreat")
            {if(L.Flag(w.March["active"])||w.Army==LegacyWorldWar.Capital(Faction))error="긴급 후퇴 불가";else {target=LegacyWorldWar.Capital(Faction);w.Begin(new JObject{{"origin",new JArray(w.Army.x,w.Army.y)},{"target",new JArray(target.x,target.y)},{"path",new JArray(new JArray(w.Army.x,w.Army.y),new JArray(target.x,target.y))},{"ration_cost",0},{"duration_seconds",Math.Max(2,LegacyWorldWar.Distance(w.Army,target)*6)},{"action","forced_retreat"}},now);}}
            else if(action=="register_garrison")
            {if(L.Flag(w.March["active"])||target!=w.Army||w.Phase(now)!="active"||!w.Register(target,force))error="주둔 위치·보급·부상·한도를 확인하세요.";}
            else if(action=="rest_army")
            {
                if(L.Flag(w.March["active"])||!new[]{"fort","citadel"}.Contains(w.Kind(w.Army))||!w.Supply(Faction).Contains(LegacyWorldWar.Key(w.Army)))error="보급 연결된 아군 요새·대성에서 정비 가능합니다.";
                else {int drop=Math.Min(20,w.Fatigue);var wounds=Map(w.State,"army_wounds");double restored=0;foreach(string id in DeployedHeroes()){double old=Math.Clamp(L.F(wounds[id],1),0,1),next=Math.Min(1,old+.15);restored+=next-old;wounds[id]=next;}int cost=40+drop*2+(int)Math.Ceiling(restored*100-.000001);if(drop==0&&restored<=0)error="이미 정비 완료";else if(w.Rations<cost)error="군량 부족";else {w.Rations-=cost;w.Fatigue-=drop;w.RemoveForce("player_local");}}
            }
            else if(action=="exchange_honor")
            {if(L.N(w.State["campaign_honor"])<50)error="전쟁 명예 부족";else {w.State["campaign_honor"]=L.N(w.State["campaign_honor"])-50;w.Rations+=200;}}
            else if(action=="claim_season_reward")
            {var reward=w.SeasonReward("local_player",now);if(!L.Flag(reward["claimable"]))error="시즌 보상 수령 불가";else {w.Rations+=L.N(reward["rations"]);w.State["campaign_honor"]=L.N(w.State["campaign_honor"])+L.N(reward["honor"]);Map(w.Season,"reward_claims")["local_player"]=reward;}}
            else if(action=="next_season")
            {if(w.Phase(now)!="ended"||L.Flag(w.SeasonReward("local_player",now)["claimable"]))error="시즌 종료 후 보상을 먼저 수령하세요.";else {long number=L.N(w.Season["season_number"],1)+1;state["faction_war"]=L.Data["initial_worlds"][Faction].DeepClone();state["faction_march"]=new JObject();state["faction_conflict"]=new JObject();state["world_season"]=new JObject{{"season_number",number}};w=World(state,now);}}
            else if(action=="prepare_rally")
            {
                if(!w.CanAttack(Faction,target)||w.Path(target).Count<2||w.Phase(now)!="active"||w.Fatigue>=85||LegacyWarBattle.Hp(WarParty(w))<=0||!w.Supply(Faction).Contains(LegacyWorldWar.Key(w.Army)))error="집결 공격 불가";
                else
                {
                    var rallies=Map(w.Conflict,"rallies");var existing=rallies.Properties().FirstOrDefault(p=>(string)p.Value["faction"]==Faction&&LegacyWorldWar.Cell(p.Value["target"])==target);
                    if(existing!=null)
                    {context=existing.Name;var list=L.Array(existing.Value["participants"]);if(!list.OfType<JObject>().Any(f=>(string)f["force_id"]=="player_local")){if(list.Count>=5)error="집결 참여 한도";else list.Add(force);}}
                    else
                    {
                        long serial=L.N(w.Conflict["next_rally_id"],1);string id="rally_"+serial;var participants=new JArray(force);
                        bool demo=w.Authority["local_demo_allies"]?.Type!=JTokenType.Boolean||L.Flag(w.Authority["local_demo_allies"]);
                        if(demo)for(int i=0;i<2;i++){double scale=.78+i*.10;int power=(int)(WarPower(w)*scale);participants.Add(new JObject{{"force_id","demo_ally_"+x+"_"+y+"_"+i},{"player_name","프로토타입 동맹 "+(i==0?"A":"B")},{"faction",Faction},{"squad",LegacyWarBattle.Garrison(Faction,target+new Vector2Int(30+i,40+i),"plain",power)},{"power",power},{"fatigue",5+i*4},{"is_npc",true},{"arrived_at",now}});}
                        rallies[id]=new JObject{{"id",id},{"target",new JArray(x,y)},{"faction",Faction},{"leader_force_id","player_local"},{"participants",participants},{"created_at",now}};w.Conflict["next_rally_id"]=serial+1;context=id;
                    }
                }
            }
            else if(action=="process_attack_queue")
            {if(L.Flag(w.March["active"])||!LegacyWorldWar.Bounds(target))error="행군 중이거나 영토를 확인해야 합니다.";else{var report=LegacyWorldAttackQueue.Process(w,target,force,now);var processed=StateCommandResult.Success((string)report["error"]??(L.Flag(report["captured"])?"대기 공격대 점령 완료":"대기 공격대 공략 종료"));processed.Details=report;return processed;}}
            else error="지원하지 않는 진영전 명령";
            if(error.Length>0)return StateCommandResult.Fail(error);w.RevisionUp();var result=StateCommandResult.Success(action=="march"||action=="support"||action=="rally_march"?"행군 시작":action=="prepare_rally"?"집결 준비 완료":"진영전 명령 처리");result.Details=new JObject{{"revision",w.Revision},{"context_id",context}};return result;
        }
        public bool WarTickDue(long now)=>WarInitialized&&(L.Flag(data["faction_march"]?["active"])&&now>=L.F(data["faction_march"]?["authority_started_unix"])+L.F(data["faction_march"]?["duration_seconds"])||now-L.N(data["faction_war"]?["last_logistics_unix"],now,long.MaxValue)>=60);
        public StateCommandResult AdvanceWar(long now=0)=>Commit(state=>
        {
            string gatewayError=GatewayError(state);if(gatewayError.Length>0)return StateCommandResult.Fail(gatewayError);now=now>0?now:L.Now;var w=World(state,now);w.AdvanceLogistics(now);if(!L.Flag(w.March["active"]))return StateCommandResult.Success("보급 갱신");
            double stamp=Math.Max(now,L.F(w.March["last_authority_unix"]));w.March["last_authority_unix"]=stamp;double elapsed=Math.Clamp(stamp-L.F(w.March["authority_started_unix"]),0,L.F(w.March["duration_seconds"]));w.March["elapsed_seconds"]=elapsed;
            if(elapsed+.0001<L.F(w.March["duration_seconds"]))return StateCommandResult.Success("행군 중");
            var target=LegacyWorldWar.Cell(w.March["target"]);var origin=LegacyWorldWar.Cell(w.March["origin"]);string action=(string)w.March["action"]??"";w.March["active"]=false;w.RevisionUp();
            bool route=action=="forced_retreat"||L.Array(w.March["path"]).Take(Math.Max(0,L.Array(w.March["path"]).Count-1)).All(p=>w.Owner(LegacyWorldWar.Cell(p))==Faction);
            if(!route){w.March["last_result"]="행군 경로 단절";return StateCommandResult.Success("행군 경로 단절 · 점령 없음");}
            if(action=="move"||action=="support"||action=="forced_retreat")
            {if(w.Owner(target)!=Faction||action=="support"&&(!w.Supply(Faction).Contains(LegacyWorldWar.Key(target))||!WarParty(w).OfType<JObject>().Any(u=>L.N(u["hp"])>0))||action=="support"&&L.Array(w.Conflict["tile_garrisons"]?[LegacyWorldWar.Key(target)]).Count>=w.Capacity(target)){w.March["last_result"]="도착 조건 변경";return StateCommandResult.Success("도착 조건 변경");}w.ArriveOwn(target);w.Register(target,Force(w));w.March["last_result"]="도착 완료";return StateCommandResult.Success("행군 도착 완료");}
            var quote=w.Quote(target); // March is inactive; revalidate ownership and origin supply.
            if(w.Phase(now)!="active"||(w.Owner(target)!= "neutral"||L.N(w.Tile(target)["guard_level"])>0)&&w.Fatigue>=85||!w.Supply(Faction).Contains(LegacyWorldWar.Key(origin))||w.Owner(target)==Faction||w.Sanctuary(target)!="neutral"||w.Owner(target)==w.Enemy&&!w.CanAttack(Faction,target))return StateCommandResult.Success("도착 시 공격 조건 변경 · 점령 없음");
            if(w.Owner(target)=="neutral"&&L.N(w.Tile(target)["guard_level"])==0){w.Tile(target)["owner"]=Faction;w.State["captured_count"]=L.N(w.State["captured_count"])+1;w.ArriveOwn(target);w.ScoreCapture(target,false,"local_player",now);w.Register(target,Force(w));w.March["last_result"]="점령 완료";return StateCommandResult.Success("점령 완료");}
            var report=ResolveWarArrival(w,target,now,(string)w.March["context_id"]??"");w.March["last_result"]=L.Flag(report["captured"])?"점령 완료":"공략 실패";w.RevisionUp();var result=StateCommandResult.Success((string)w.March["last_result"]);result.Details=report;return result;
        });
        JObject ResolveWarArrival(LegacyWorldWar w,Vector2Int target,long now,string rallyId)
        {
            string key=LegacyWorldWar.Key(target);bool neutral=w.Owner(target)=="neutral";int guard=(int)L.N(w.Tile(target)["guard_level"],0,5);var initial=WarParty(w);var attackers=(JArray)initial.DeepClone();var results=new JArray();bool captured=false;int defeated=0,used=0;JObject winning=null;JArray winningUnits=null;
            var forces=L.Array(w.Conflict["tile_garrisons"]?[key]);
            if(neutral)
            {var defenders=L.Array(w.State["garrisons"]?[key]);if(defenders.Count==0&&guard>0)defenders=new JArray(LegacyWarBattle.Garrison("neutral",target,w.Kind(target),600+guard*350).Take(Math.Min(10,2+guard*2)).Select((u,i)=>{var v=(JObject)u.DeepClone();v["id"]="militia_"+target.x+"_"+target.y+"_"+i;v["name"]="Lv."+guard+" 영토 수비대 "+(i+1);return v;}));forces=new JArray(new JObject{{"squad",defenders},{"force_id","neutral_guard"},{"player_name","영토 수비대"}});}
            else if(forces.Count==0)
            {
                var legacy=L.Array(w.State["garrisons"]?[key]);int count=w.Kind(target)=="capital"?5:w.Kind(target)=="citadel"?4:w.Kind(target)=="fort"?3:new[]{"mine","forest_resource","ruins"}.Contains(w.Kind(target))?2:1;
                if(legacy.Count>0)forces=new JArray(new JObject{{"squad",legacy.DeepClone()},{"force_id","legacy_"+key},{"player_name","기존 수비대"}});
                else for(int i=0;i<Math.Min(w.Capacity(target),count);i++)forces.Add(new JObject{{"force_id","npc_"+key+"_"+i},{"player_name","전선 수비대 "+(i+1)},{"squad",LegacyWarBattle.Garrison(w.Enemy,target+new Vector2Int(i,i*2),w.Kind(target),(int)(Math.Max(700,WarPower(w))*(.82+i*.08)))},{"faction",w.Enemy},{"is_npc",true}});
            }
            var participants=new JArray(Force(w));if(rallyId.Length>0&&w.Conflict["rallies"]?[rallyId] is JObject rally)participants=L.Array(rally["participants"]);
            var remaining=new JArray(forces.Select(f=>f.DeepClone()));
            foreach(var participant in participants.OfType<JObject>().Take(5))
            {
                used++;bool local=(string)participant["force_id"]=="player_local";var current=local?attackers:L.Array(participant["squad"]);int index=0;
                while(index<remaining.Count&&LegacyWarBattle.Hp(current)>0)
                {
                    var defender=(JObject)remaining[index];double defense=neutral?w.Kind(target)=="forest"?1.08:w.Kind(target)=="hills"?1.12:w.Kind(target)=="fort"?1.18:w.Kind(target)=="citadel"?1.24:w.Kind(target)=="mine"?1.05:w.Kind(target)=="forest_resource"?1.08:w.Kind(target)=="ruins"?1.10:1:w.Defense(target,w.Enemy);
                    var battle=LegacyWarBattle.Resolve(current,L.Array(defender["squad"]),local?w.Fatigue:(int)L.N(participant["fatigue"],0,100),defense,(string)participant["stance"]??"balanced",(int)(w.Revision%1000000)+target.x*97+target.y*13+results.Count*97+1);results.Add(battle);current=L.Array(battle["attacker_units"]);if(local)attackers=current;
                    if(L.Flag(battle["victory"])){remaining.RemoveAt(index);defeated++;if(local&&!neutral)w.Conflict["contribution_points"]=L.N(w.Conflict["contribution_points"])+25;}
                    else {defender["squad"]=battle["defender_units"].DeepClone();break;}
                }
                if(remaining.Count==0){captured=true;winning=participant;winningUnits=current;break;}
            }
            var wounds=Map(w.State,"army_wounds");foreach(var unit in initial.OfType<JObject>()){var survivor=attackers.OfType<JObject>().FirstOrDefault(u=>(string)u["id"]==(string)unit["id"]);wounds[(string)unit["id"]]=survivor==null?0:L.N(survivor["hp"])/(double)Math.Max(1,L.N(survivor["max_hp"]));}
            if(captured)
            {w.Tile(target)["owner"]=Faction;w.State["captured_count"]=L.N(w.State["captured_count"])+1;Map(w.State,"garrisons").Remove(key);Map(w.Conflict,"tile_garrisons").Remove(key);w.ArriveOwn(target);w.Fatigue+=neutral?12:rallyId.Length>0?10+used*2:12+defeated*3;if(winning!=null&&(string)winning["force_id"]!="player_local"){var winner=(JObject)winning.DeepClone();winner["squad"]=winningUnits;w.Register(target,winner);}w.Register(target,Force(w));w.ScoreCapture(target,!neutral,"local_player",now);if(!neutral){w.Conflict["total_captures"]=L.N(w.Conflict["total_captures"])+1;w.Conflict["contribution_points"]=L.N(w.Conflict["contribution_points"])+100;}}
            else
            {w.Fatigue+=neutral?20:rallyId.Length>0?15+used*3:20+defeated*4;if(!neutral)w.ScoreDefense(w.Enemy,now);if(neutral)Map(w.State,"garrisons")[key]=remaining.Count>0?remaining[0]["squad"].DeepClone():new JArray();else Map(w.Conflict,"tile_garrisons")[key]=remaining;w.Register(w.Army,Force(w));}
            Map(w.Conflict,"rallies").Remove(rallyId);var report=new JObject{{"captured",captured},{"victory",captured},{"target",new JArray(target.x,target.y)},{"timestamp",now},{"fatigue_after",w.Fatigue},{"defeated_forces",defeated},{"remaining_defenders",remaining.Count},{"participants_used",used},{"attacker_units",attackers},{"battle_summaries",results},{"neutral_campaign",neutral}};
            var reports=L.Array(w.State["battle_reports"]);reports.Insert(0,report);while(reports.Count>10)reports.RemoveAt(reports.Count-1);w.State["battle_reports"]=reports;var campaigns=L.Array(w.Conflict["campaign_reports"]);campaigns.Insert(0,report.DeepClone());while(campaigns.Count>20)campaigns.RemoveAt(campaigns.Count-1);w.Conflict["campaign_reports"]=campaigns;return report;
        }
    }
}
