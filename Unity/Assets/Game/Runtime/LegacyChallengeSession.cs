using System;
using System.Collections.Generic;
using System.Linq;
using Newtonsoft.Json.Linq;
using L=Eternal.UnityMigration.LegacyFeatureCatalog;

namespace Eternal.UnityMigration
{
    // Runtime receipt, never deserialized from a save or accepted from a UI token.
    public sealed class LegacyChallengeSession
    {
        public enum Outcome { Running,Won,Lost,Cancelled,Settled }
        public Outcome State {get;private set;}=Outcome.Running;
        public readonly long Serial;
        public readonly string Mode,Variant,Title,Objective,Pattern;
        public readonly int RequiredWaves;
        public readonly double Limit;
        public readonly JObject Entry;
        public double Elapsed {get;private set;}
        public int Waves {get;private set;}
        public long Damage {get;private set;}
        public string Reason {get;private set;}="";
        readonly Dictionary<int,int> lowest=new();
        public readonly NativeChallengeCombatLedger Ledger=new();
        public bool Running=>State==Outcome.Running;
        public bool PatternActive=>Pattern.Length>0&&(Mode=="tower"?Waves==RequiredWaves-1:Mode=="weekly"&&Waves>=1);
        public LegacyChallengeSession(long serial,JObject entry)
        {
            if(serial<1||entry==null)throw new ArgumentException("Reserved challenge entry required.");
            Serial=serial;Entry=(JObject)entry.DeepClone();Mode=(string)entry["mode"];Variant=(string)entry["variant"]??"";
            int floor=(int)L.N(entry["floor"],1,9999);Limit=Mode=="daily"?60:90;
            Objective=Mode=="weekly"?"score":Mode=="daily"&&Variant=="survival"?"survive":"waves";
            RequiredWaves=Mode=="tower"?(floor%5==0?3:2):Mode=="daily"?(Variant=="gold_rush"?3:Variant=="boss_hunt"?1:0):0;
            Title=Mode=="tower"?"무한탑 "+floor+"층":Mode=="weekly"?"주간 심연":(string)L.Data["daily_plans"]?[Variant]?["title"]??"일일 던전";
            int patternIndex=Mode=="tower"&&floor>=10?(floor-10)%3:Mode=="weekly"&&long.TryParse((string)entry["week"],out var week)?(int)(week%3):-1;
            Pattern=patternIndex<0?"":new[]{"healing_guard","charged_strike","split_pack"}[patternIndex];
        }
        public void Register(IEnumerable<Combatant> enemies)
        {lowest.Clear();foreach(var e in enemies.Where(e=>e.Alive))lowest[e.Serial]=e.Hp;}
        public void ObserveHp(Combatant enemy,int before,int after)
        {if(!Running||Elapsed>=Limit||!lowest.TryGetValue(enemy.Serial,out int low)||before<=0||after<0||after>=before)return;Damage=Math.Min(1000000000000,Damage+Math.Max(0,Math.Min(low,before)-after));lowest[enemy.Serial]=Math.Min(low,after);}
        public void CompleteWave(int enemies,int heroes)
        {if(!Running||lowest.Count==0||enemies>0||heroes<=0)return;Waves++;lowest.Clear();if(Objective=="waves"&&Waves>=RequiredWaves){State=Outcome.Won;Reason="waves_cleared";}}
        public void Advance(double dt,int aliveHeroes)
        {
            if(!Running||dt<=0||!double.IsFinite(dt))return;Elapsed=Math.Min(Limit,Elapsed+dt);
            if(aliveHeroes<=0){State=Outcome.Lost;Reason="party_defeated";return;}
            if(Elapsed+0.00001<Limit)return;
            if(Objective=="score"&&Damage>0&&(lowest.Count>0||Waves>0)){State=Outcome.Won;Reason="score_complete";}
            else if(Objective=="survive"&&(lowest.Count>0||Waves>0)){State=Outcome.Won;Reason="survived";}
            else {State=Outcome.Lost;Reason=Objective=="score"?"no_damage":"timeout";}
        }
        public void Cancel(){if(Running){State=Outcome.Cancelled;Reason="left_screen";}}
        internal bool Consume(long expected){if(State!=Outcome.Won||Serial!=expected)return false;State=Outcome.Settled;return true;}
        public JObject Report()
        {var result=BaseReport();if(attached){foreach(var field in Ledger.Snapshot(Elapsed,Damage).Properties())result[field.Name]=field.Value.DeepClone();}
            result["comparison_key"]=new JArray(Pattern,L.Flag(Entry["practice"]),Mode,Variant,Entry["faction"],Entry["zone"],Mode=="tower"?Entry["floor"]:Mode=="daily"?Entry["run_index"]:0,Mode=="weekly"?Entry["week"]:"",Entry["level_mode"]??"actual",Entry["match_level"]??0).ToString(Newtonsoft.Json.Formatting.None);return result;}
        bool attached;
        public void AttachLedger(CombatEncounter battle,OriginalCombatCatalog catalog){Ledger.Begin(battle,catalog,battle.SkillsAuto,battle.UltimateAuto);attached=true;}
        JObject BaseReport()=>new(){{"serial",Serial},{"mode",Mode},{"variant",Variant},{"entry",Entry.DeepClone()},{"elapsed",Elapsed},{"waves",Waves},{"damage_score",Damage},{"reason",Reason},{"outcome",State.ToString().ToLowerInvariant()}};
    }

    public sealed partial class GameStateCommands
    {
        void RefreshChallengePeriods(JObject state,long now)
        {
            string day=L.Day(now),old=L.ValidDay(state["daily_dungeon_day"]);
            if(old.Length==0||string.CompareOrdinal(day,old)>0){state["daily_dungeon_day"]=day;state["daily_dungeon_runs"]=0;}
            string week=L.Week(now),previous=L.ValidWeek(state["weekly_content_key"]);
            if(previous.Length==0||long.Parse(week)>long.Parse(previous)){state["weekly_content_key"]=week;state["weekly_trial_runs"]=0;state["weekly_trial_best"]=0;}
            state["tower_floor"]=Integer(state["tower_floor"],1,1,10000);state["tower_best_floor"]=Integer(state["tower_best_floor"],0,0,9999);
        }
        public JObject ChallengeStatus(long now=0)
        {var state=Snapshot();RefreshChallengePeriods(state,now>0?now:L.Now);return new JObject{{"daily_day",state["daily_dungeon_day"]},{"daily_runs",L.N(state["daily_dungeon_runs"],0,3)},{"floor",state["tower_floor"]},{"best_floor",state["tower_best_floor"]},{"week",state["weekly_content_key"]},{"weekly_runs",L.N(state["weekly_trial_runs"],0,5)},{"weekly_best",L.N(state["weekly_trial_best"],0,CurrencyCap)}};}
        public StateCommandResult ReserveChallenge(string mode,string variant="gold_rush",long now=0)=>Commit(state=>
        {
            now=now>0?now:L.Now;RefreshChallengePeriods(state,now);
            if(!UnityPlayer||DeployedHeroes().Count==0||!new[]{"daily","tower","weekly"}.Contains(mode))return StateCommandResult.Fail("진영과 원정대를 확인하세요.");
            if(mode=="daily"&&(!new[]{"gold_rush","survival","boss_hunt"}.Contains(variant)||(string)state["daily_dungeon_day"]!=L.Day(now)||L.N(state["daily_dungeon_runs"])>=3))return StateCommandResult.Fail("오늘 던전 완료 횟수는 3회까지입니다.");
            if(mode=="weekly"&&((string)state["weekly_content_key"]!=L.Week(now)||L.N(state["weekly_trial_runs"])>=5))return StateCommandResult.Fail("이번 주 심연 완료 횟수는 5회까지입니다.");
            if(mode=="tower"&&(L.N(state["tower_floor"],1)>9999||L.N(state["tower_best_floor"])>=L.N(state["tower_floor"],1)))return StateCommandResult.Fail("무한탑 기록을 확인하세요.");
            long serial=Integer(state["unity_challenge_serial"],0,0,CurrencyCap-1)+1;state["unity_challenge_serial"]=serial;
            var entry=new JObject{{"mode",mode},{"variant",variant},{"faction",Faction},{"zone",UnityZone},{"hero_ids",new JArray(DeployedHeroes())},{"day",state["daily_dungeon_day"]},{"week",state["weekly_content_key"]},{"run_index",mode=="daily"?L.N(state["daily_dungeon_runs"]):L.N(state["weekly_trial_runs"])},{"best",L.N(state["weekly_trial_best"],0,CurrencyCap)},{"floor",state["tower_floor"]},{"best_floor",state["tower_best_floor"]}};
            state["unity_challenge_active"]=new JObject{{"serial",serial},{"entry",entry}};var result=StateCommandResult.Success("도전 입장");result.Details=new JObject{{"serial",serial},{"entry",entry.DeepClone()}};return result;
        });
        public StateCommandResult FinishChallenge(LegacyChallengeSession session,long now=0)=>Commit(state=>
        {
            now=now>0?now:L.Now;var active=L.Object(state["unity_challenge_active"]);
            if(session==null||L.N(active["serial"],0,CurrencyCap)!=session.Serial||!JToken.DeepEquals(active["entry"],session.Entry))return StateCommandResult.Fail("이미 처리했거나 유효하지 않은 도전입니다.");
            if(session.Running)return StateCommandResult.Fail("전투가 진행 중입니다.");
            bool context=(string)session.Entry["faction"]==Faction&&(string)session.Entry["zone"]==UnityZone&&JToken.DeepEquals(session.Entry["hero_ids"],new JArray(DeployedHeroes()));
            RefreshChallengePeriods(state,now);string mode=session.Mode;
            if(mode=="daily")context&=(string)session.Entry["day"]==L.Day(now)&&(string)state["daily_dungeon_day"]==L.Day(now)&&L.N(session.Entry["run_index"])==L.N(state["daily_dungeon_runs"]);
            if(mode=="weekly")context&=(string)session.Entry["week"]==L.Week(now)&&(string)state["weekly_content_key"]==L.Week(now)&&L.N(session.Entry["run_index"])==L.N(state["weekly_trial_runs"])&&L.N(session.Entry["best"],0,CurrencyCap)==L.N(state["weekly_trial_best"],0,CurrencyCap);
            if(mode=="tower")context&=L.N(session.Entry["floor"])==L.N(state["tower_floor"])&&L.N(session.Entry["best_floor"])==L.N(state["tower_best_floor"]);
            bool won=context&&session.State==LegacyChallengeSession.Outcome.Won&&session.Consume(session.Serial);
            var report=session.Report();report["settled"]=won;state["unity_last_challenge"]=report;state.Remove("unity_challenge_active");
            if(!won)return StateCommandResult.Success(context?"도전 종료 · 보상 없음":"입장 조건 변경 · 보상 없음");
            JObject reward;
            if(mode=="daily")
            {int run=(int)L.N(state["daily_dungeon_runs"],0,2);reward=(JObject)L.Data["daily_rewards"][run];state["daily_dungeon_runs"]=run+1;Map(state,"daily_dungeon_clears")[Faction+":"+session.Variant+":"+run]=true;GoalRecord(state,"daily_clear");DistributeXp(state,(int)L.N(reward["xp"]));AddCurrency(state,"wallet_xp",L.N(reward["xp"]));GrantPetXp(state,(int)L.N(reward["pet_xp"]));}
            else if(mode=="tower")
            {int floor=(int)L.N(session.Entry["floor"],1,9999);reward=new JObject{{"gold",250+floor*90},{"gems",2+floor/5}};state["tower_best_floor"]=floor;state["tower_floor"]=floor+1;GoalRecord(state,"tower_clear");}
            else
            {int run=(int)L.N(state["weekly_trial_runs"],0,4);reward=(JObject)L.Data["weekly_rewards"][run];state["weekly_trial_runs"]=run+1;state["weekly_trial_best"]=Math.Max(L.N(state["weekly_trial_best"],0,CurrencyCap),session.Damage);DistributeXp(state,(int)L.N(reward["hero_xp"]));GoalRecord(state,"abyss_clear");}
            AddCurrency(state,"wallet_gold",L.N(reward["gold"]));AddCurrency(state,"wallet_gems",L.N(reward["gems"]));report["reward"]=reward.DeepClone();return StateCommandResult.Success("도전 완료 · 골드 +"+reward["gold"]+" · 젬 +"+L.N(reward["gems"]),L.N(reward["gold"]));
        });
        public StateCommandResult SweepDaily(string variant,long now=0)=>Commit(state=>
        {
            now=now>0?now:L.Now;RefreshChallengePeriods(state,now);int run=(int)L.N(state["daily_dungeon_runs"],0,3);string key=Faction+":"+variant+":"+run;
            if(run>=3||(string)state["daily_dungeon_day"]!=L.Day(now)||!L.Flag(state["daily_dungeon_clears"]?[key]))return StateCommandResult.Fail("같은 진영·종류·단계의 직접 승리 기록이 필요합니다.");
            var reward=(JObject)L.Data["daily_rewards"][run];state["daily_dungeon_runs"]=run+1;AddCurrency(state,"wallet_gold",L.N(reward["gold"]));AddCurrency(state,"wallet_xp",L.N(reward["xp"]));DistributeXp(state,(int)L.N(reward["xp"]));GrantPetXp(state,(int)L.N(reward["pet_xp"]));GoalRecord(state,"daily_clear");return StateCommandResult.Success("던전 소탕 · 골드 +"+reward["gold"],L.N(reward["gold"]));
        });
    }
}
