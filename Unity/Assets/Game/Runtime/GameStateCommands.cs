using System;
using System.Collections.Generic;
using System.Globalization;
using System.Linq;
using Newtonsoft.Json.Linq;

namespace Eternal.UnityMigration
{
    public sealed class StateCommandResult
    {
        public bool Ok,SavePending;
        public string Message;
        public long Gold,Xp;
        public static StateCommandResult Fail(string message)=>new(){Message=message};
        public static StateCommandResult Success(string message,long gold=0,long xp=0)=>new(){Ok=true,Message=message,Gold=gold,Xp=xp};
    }
    // One mutable owner for an intact original save payload. Unknown fields and
    // faction/world/preset data survive every supported command and snapshot.
    // Storage failures retain the awarded snapshot; RetrySave never replays it.
    public sealed partial class GameStateCommands
    {
        public const long CurrencyCap=1000000000000;
        readonly OriginalCombatCatalog catalog;
        readonly Dictionary<string,string> heroFactions=new(StringComparer.Ordinal);
        readonly Dictionary<string,int> baseGrades=new(StringComparer.Ordinal);
        readonly Func<JObject,bool> store;
        JObject data;
        public bool SavePending {get;private set;}
        public bool FutureVersionBlocked {get;private set;}
        public bool PracticeActive;
        public string LastSaveStatus {get;private set;}="not_saved";
        public GameStateCommands(OriginalCombatCatalog catalog,JObject originalPayload,Func<JObject,bool> saveSnapshot,bool futureVersion=false)
        {
            this.catalog=catalog;data=(JObject)originalPayload.DeepClone();store=saveSnapshot;FutureVersionBlocked=futureVersion;
            FutureVersionBlocked|=Integer(data["save_version"],1,1,int.MaxValue)>LegacySaveCodec.Version;
            var factionIndices=new Dictionary<string,int>(StringComparer.Ordinal);
            foreach(string id in catalog.HeroIds)
            {string faction=(string)catalog.Hero(id)["faction"];int index=factionIndices.GetValueOrDefault(faction);heroFactions[id]=faction;baseGrades[id]=index>=7?2:index>=3?1:0;factionIndices[faction]=index+1;}
            // Normalize existing research records against their level budget at
            // the load boundary, before a rejected upgrade can expose old ranks.
            // Keep unknown fields and do not create records for unrelated heroes.
            if(data["hero_skill_tree"] is JObject trees)
                foreach(var property in trees.Properties().ToArray())if(ValidHero(data,property.Name)&&property.Value is JObject)Tree(data,property.Name);
        }
        public JObject Snapshot()=>(JObject)data.DeepClone();
        public long WalletGold=>Integer(data["wallet_gold"],0,0,CurrencyCap);
        public long WalletGems=>Integer(data["wallet_gems"],0,0,CurrencyCap);
        public string Faction=>data["selected_faction"]?.Type==JTokenType.String?(string)data["selected_faction"]:"";
        public string MutationError=>FutureVersionBlocked?"최신 버전의 저장 기록을 먼저 확인해 주세요.":PracticeActive?"연습을 마친 뒤 성장과 재화를 변경하세요.":SavePending?"기록 저장 대기 중이에요. 먼저 다시 저장해 주세요.":"";
        public bool RetrySave(){if(!SavePending||FutureVersionBlocked)return false;Save();return !SavePending;}
        void Save()
        {
            SavePending=true;
            try{if(store!=null&&store(Snapshot())){SavePending=false;LastSaveStatus="saved";}else LastSaveStatus="save_failed";}
            catch(System.IO.IOException){LastSaveStatus="save_failed";}
            catch(UnauthorizedAccessException){LastSaveStatus="save_failed";}
        }
        StateCommandResult Commit(Func<JObject,StateCommandResult> operation)
        {
            if(MutationError.Length>0)return StateCommandResult.Fail(MutationError);
            var draft=Snapshot();var result=operation(draft);if(!result.Ok)return result;
            data=draft;Save();result.SavePending=SavePending;return result;
        }
        bool ValidHero(JObject state,string id)=>id!=null&&heroFactions.TryGetValue(id,out var faction)&&state["selected_faction"]?.Type==JTokenType.String&&faction==(string)state["selected_faction"];
        static JObject Map(JObject root,string key){if(root[key] is JObject map)return map;map=new JObject();root[key]=map;return map;}
        static JObject Entry(JObject root,string field,string id){var map=Map(root,field);if(map[id] is JObject entry)return entry;entry=new JObject();map[id]=entry;return entry;}
        public static long Integer(JToken token,long fallback,long minimum,long maximum)
        {
            if(token==null||token.Type!=JTokenType.Integer&&token.Type!=JTokenType.Float)return fallback;
            double n;try{var value=((JValue)token).Value;n=value is System.Numerics.BigInteger big?(double)big:Convert.ToDouble(value,CultureInfo.InvariantCulture);}catch(Exception e)when(e is FormatException||e is InvalidCastException||e is OverflowException){return fallback;}
            if(!double.IsFinite(n))return fallback;return (long)Math.Clamp(n,minimum,maximum);
        }
        static void AddCurrency(JObject state,string key,long amount)=>state[key]=Math.Clamp(Integer(state[key],0,0,CurrencyCap)+Math.Clamp(amount,0,CurrencyCap),0,CurrencyCap);
        static JObject Progress(JObject state,string id)
        {
            var progress=Entry(state,"hero_progress",id);int level=(int)Integer(progress["level"],1,1,100);
            progress["level"]=level;progress["xp"]=level>=100?0:Integer(progress["xp"],0,0,100000000);return progress;
        }
        public (int level,int xp) HeroProgress(string id)
        {
            if(!ValidHero(data,id))return (1,0);
            var p=(data["hero_progress"] as JObject)?[id] as JObject;int level=(int)Integer(p?["level"],1,1,100);return (level,level>=100?0:(int)Integer(p?["xp"],0,0,100000000));
        }
        static JObject Tree(JObject state,string id)
        {
            int budget=Math.Clamp(((int)Progress(state,id)["level"]-1)/3,0,30);var tree=Entry(state,"hero_skill_tree",id);
            foreach(string branch in new[]{"offense","survival","utility"}){int rank=(int)Integer(tree[branch],0,0,Math.Min(10,budget));tree[branch]=rank;budget-=rank;}return tree;
        }
        public (int offense,int survival,int utility,int available) HeroTree(string id)
        {
            if(!ValidHero(data,id))return (0,0,0,0);int budget=Math.Min(30,(HeroProgress(id).level-1)/3);
            var tree=(data["hero_skill_tree"] as JObject)?[id] as JObject;
            int o=(int)Integer(tree?["offense"],0,0,Math.Min(10,budget));budget-=o;
            int s=(int)Integer(tree?["survival"],0,0,Math.Min(10,budget));budget-=s;
            int u=(int)Integer(tree?["utility"],0,0,Math.Min(10,budget));budget-=u;
            return (o,s,u,budget);
        }
        public StateCommandResult UpgradeResearch(string id,string branch)=>Commit(state=>
        {
            if(!ValidHero(state,id)||branch!="offense"&&branch!="survival"&&branch!="utility")return StateCommandResult.Fail("영웅 또는 연구 항목을 확인하세요.");
            var tree=Tree(state,id);int spent=(int)tree["offense"]+(int)tree["survival"]+(int)tree["utility"];
            int points=Math.Min(30,((int)Progress(state,id)["level"]-1)/3);
            if(points<=spent||(int)tree[branch]>=10)return StateCommandResult.Fail("사용 가능한 스킬 포인트가 없습니다.");
            tree[branch]=(int)tree[branch]+1;return StateCommandResult.Success("연구 단계가 올랐습니다.");
        });
        int BaseGrade(JObject state,string id)
        {
            return baseGrades.GetValueOrDefault(id);
        }
        public string Grade(string id)
        {if(!ValidHero(data,id))return "R";int asc=(int)Integer((data["hero_ascension"] as JObject)?[id],0,0,3);return new[]{"R","SR","SSR","UR"}[Math.Min(3,BaseGrade(data,id)+asc)];}
        public StateCommandResult Ascend(string id)=>Commit(state=>
        {
            if(!ValidHero(state,id))return StateCommandResult.Fail("현재 진영의 영웅을 선택하세요.");
            var map=Map(state,"hero_ascension");int asc=(int)Integer(map[id],0,0,3);
            if(BaseGrade(state,id)+asc>=3)return StateCommandResult.Fail("이미 최고 등급 UR입니다.");
            int requiredLevel=10+asc*10,cost=1200+asc*1800;
            if((int)Progress(state,id)["level"]<requiredLevel)return StateCommandResult.Fail("승급에는 Lv."+requiredLevel+"가 필요합니다.");
            long gold=Integer(state["wallet_gold"],0,0,CurrencyCap);if(gold<cost)return StateCommandResult.Fail("승급 골드가 부족합니다.");
            state["wallet_gold"]=gold-cost;map[id]=asc+1;return StateCommandResult.Success("영웅 등급이 올랐습니다.",-cost);
        });
        public StateCommandResult Breakthrough(string id)=>Commit(state=>
        {
            if(!ValidHero(state,id))return StateCommandResult.Fail("현재 진영의 영웅을 선택하세요.");
            var ranks=Map(state,"hero_breakthrough");var shards=Map(state,"hero_shards");int rank=(int)Integer(ranks[id],0,0,5),cost=20+rank*20;
            if(rank>=5)return StateCommandResult.Fail("이미 최대 돌파입니다.");long count=Integer(shards[id],0,0,CurrencyCap);
            if(count<cost)return StateCommandResult.Fail("영웅 조각이 부족합니다.");
            shards[id]=count-cost;ranks[id]=rank+1;return StateCommandResult.Success("영웅 돌파 단계가 올랐습니다.");
        });
        static string Day(string value)=>DateTime.TryParseExact(value,"yyyy-MM-dd",CultureInfo.InvariantCulture,DateTimeStyles.None,out var date)?date.ToString("yyyy-MM-dd",CultureInfo.InvariantCulture):"";
        public StateCommandResult ClaimDaily(string day)=>Commit(state=>
        {
            day=Day(day);if(day.Length==0)return StateCommandResult.Fail("날짜를 확인하세요.");string previous=Day((string)state["daily_reward_claimed_day"]??"");
            if(previous.Length>0&&string.CompareOrdinal(day,previous)<=0)return StateCommandResult.Fail("오늘의 보상은 이미 받았습니다.");
            state["daily_reward_claimed_day"]=day;AddCurrency(state,"wallet_gems",30);AddCurrency(state,"unclaimed_gold",100);
            return StateCommandResult.Success("일일 보상 · 젬 +30 · 골드 +100",100);
        });
        public StateCommandResult ClaimSupport(string day)=>Commit(state=>
        {
            day=Day(day);if(day.Length==0)return StateCommandResult.Fail("날짜를 확인하세요.");string previous=Day((string)state["rewarded_ad_day"]??"");
            if(previous.Length==0||string.CompareOrdinal(day,previous)>0){state["rewarded_ad_day"]=day;state["rewarded_ad_claimed_count"]=0;}
            int count=(int)Integer(state["rewarded_ad_claimed_count"],0,0,3);if(count>=3)return StateCommandResult.Fail("오늘의 지원 보상을 모두 받았습니다.");
            state["rewarded_ad_claimed_count"]=count+1;AddCurrency(state,"wallet_gems",5);AddCurrency(state,"unclaimed_gold",50);
            return StateCommandResult.Success("지원 보상 · 젬 +5 · 골드 +50",50);
        });
        public StateCommandResult ClaimHuntingRewards()=>Commit(state=>
        {
            long gold=Integer(state["unclaimed_gold"],0,0,CurrencyCap)+Integer(state["idle_chest_gold"],0,0,CurrencyCap);
            long xp=Integer(state["unclaimed_xp"],0,0,CurrencyCap)+Integer(state["idle_chest_xp"],0,0,CurrencyCap);
            if(gold==0&&xp==0)return StateCommandResult.Fail("받을 보상이 없습니다.");
            AddCurrency(state,"wallet_gold",gold);AddCurrency(state,"wallet_xp",xp);
            foreach(string key in new[]{"unclaimed_gold","unclaimed_xp","idle_chest_gold","idle_chest_xp"})state[key]=0;
            return StateCommandResult.Success("사냥 보상을 수령했습니다.",gold,xp);
        });
        public StateCommandResult AwardHeroXp(int amount)=>Commit(state=>
        {
            if(amount<=0)return StateCommandResult.Fail("경험치가 없습니다.");
            int applied=DistributeXp(state,amount);return StateCommandResult.Success("영웅 경험치 총 +"+applied+" 분배",xp:applied);
        });
        int DistributeXp(JObject state,int amount)
        {
            var recipients=new List<string>();var drafts=new Dictionary<string,JObject>(StringComparer.Ordinal);
            foreach(var token in state["deployed_hero_ids"] as JArray??new JArray())
            {
                if(token.Type!=JTokenType.String)continue;string id=(string)token;
                if(!ValidHero(state,id)||drafts.ContainsKey(id))continue;var progress=(JObject)Progress(state,id).DeepClone();
                if((int)progress["level"]>=100)continue;recipients.Add(id);drafts.Add(id,progress);
            }
            int total=Math.Min(amount,100000000),remaining=total;
            while(remaining>0&&recipients.Count>0)
            {
                // Stable ordering preserves the source per-award remainder rule.
                recipients=recipients.OrderBy(id=>(int)drafts[id]["level"]).ThenBy(id=>(int)drafts[id]["xp"]).ToList();
                int pool=remaining,count=recipients.Count,per=pool/count,remainder=pool%count;var next=new List<string>();
                for(int i=0;i<count;i++)
                {
                    string id=recipients[i];var progress=drafts[id];int allocated=per+(i<remainder?1:0),level=(int)progress["level"],xp=(int)progress["xp"]+allocated;
                    while(level<100){int required=LegacyGrowthEconomy.XpCost(level,100);if(xp<required)break;xp-=required;level++;}
                    int unused=0;if(level>=100){unused=Math.Min(allocated,Math.Max(0,xp));xp=0;}else next.Add(id);
                    progress["level"]=level;progress["xp"]=xp;remaining-=allocated-unused;
                }
                if(remaining==pool&&next.Count==count)throw new InvalidOperationException("XP redistribution stalled.");
                recipients=next;
            }
            var map=Map(state,"hero_progress");foreach(var pair in drafts)map[pair.Key]=pair.Value;return total-remaining;
        }
    }
}
