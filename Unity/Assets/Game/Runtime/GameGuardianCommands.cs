using System;
using System.Linq;
using Newtonsoft.Json.Linq;

namespace Eternal.UnityMigration
{
    public sealed partial class GameStateCommands
    {
        static readonly string[] GuardianTiers={"고급","희귀","에픽","전설","신화"};
        static readonly int[] GuardianWeights={55,27,12,5,1};
        // Canonical JSON objects are sorted for save integrity. Draw indexing
        // must retain GuardianCatalog's authored order, not sorted JSON order.
        static readonly string[] GuardianIds={"lumi","umbra","moss","tide","thunder","dawn","phoenix","leviathan","origin","eclipse"};
        static void Starter(JObject state)
        {
            string faction=(string)state["selected_faction"],id=faction=="aurelia"?"lumi":faction=="noxfera"?"umbra":"";if(id.Length==0)return;
            var collection=Map(state,"guardian_collection");if(collection[id]==null)collection[id]=new JObject{{"copies",1}};
            string current=state["guardian_equipped"]?.Type==JTokenType.String?(string)state["guardian_equipped"]:"";
            if(collection[current]==null||GuardianDefinitions[current]==null)state["guardian_equipped"]=id;
        }
        public JObject GuardianProfile(string id)=>GuardianDefinitions[id] is JObject profile?(JObject)profile.DeepClone():new JObject();
        public string[] OwnedGuardians()
        {var collection=data["guardian_collection"] as JObject;return GuardianIds.Where(id=>collection?[id] is JObject).ToArray();}
        public bool GuardianFreeAvailable=>data["guardian_free_claimed"]?.Type!=JTokenType.Boolean||!(bool)data["guardian_free_claimed"];
        public int GuardianMythicPity=>(int)Integer(data["guardian_mythic_pity"],0,0,79);
        public int GuardianLegendaryPity=>(int)Integer(data["guardian_legendary_pity"],0,0,29);
        public int GuardianCopies(string id)=>(int)Integer(((data["guardian_collection"] as JObject)?[id] as JObject)?["copies"],0,0,999);
        public StateCommandResult EquipGuardian(string id)=>Commit(state=>
        {
            if((state["guardian_collection"] as JObject)?[id] is not JObject||GuardianDefinitions[id] is not JObject)return StateCommandResult.Fail("보유한 수호신을 선택하세요.");
            state["guardian_equipped"]=id;return StateCommandResult.Success((string)GuardianDefinitions[id]["name"]+" 장착");
        });
        public static string DrawGuardian(Func<int,int,int> inclusiveRandom,int mythicPity,int legendaryPity)
        {
            int tier;if(mythicPity>=79)tier=4;else if(legendaryPity>=29)tier=3;
            else{int roll=inclusiveRandom(1,100);if(roll<1||roll>100)throw new ArgumentOutOfRangeException(nameof(inclusiveRandom));tier=0;while(roll>GuardianWeights[tier])roll-=GuardianWeights[tier++];}
            var choices=GuardianIds.Where(id=>(string)GuardianDefinitions[id]["tier"]==GuardianTiers[tier]).ToArray();int index=inclusiveRandom(0,choices.Length-1);
            if(index<0||index>=choices.Length)throw new ArgumentOutOfRangeException(nameof(inclusiveRandom));return choices[index];
        }
        public StateCommandResult SummonGuardian(System.Random random)=>SummonGuardian((low,high)=>random.Next(low,high+1));
        internal StateCommandResult SummonGuardian(Func<int,int,int> random)=>Commit(state=>
        {
            string faction=(string)state["selected_faction"];if(faction!="aurelia"&&faction!="noxfera")return StateCommandResult.Fail("진영을 먼저 선택하세요.");
            bool free=state["guardian_free_claimed"]?.Type!=JTokenType.Boolean||!(bool)state["guardian_free_claimed"];long gems=Integer(state["wallet_gems"],0,0,CurrencyCap);
            if(!free&&gems<80)return StateCommandResult.Fail("수호신 소환에는 젬 80개가 필요합니다.");
            Starter(state);int myth=(int)Integer(state["guardian_mythic_pity"],0,0,79),legend=(int)Integer(state["guardian_legendary_pity"],0,0,29);
            string id=DrawGuardian(random,myth,legend);var profile=(JObject)GuardianDefinitions[id];var collection=Map(state,"guardian_collection");bool first=collection[id]==null;
            int copies=Math.Min(999,(int)Integer((collection[id] as JObject)?["copies"],0,0,999)+1);collection[id]=new JObject{{"copies",copies}};
            if(free)state["guardian_free_claimed"]=true;else state["wallet_gems"]=gems-80;
            int tier=Array.IndexOf(GuardianTiers,(string)profile["tier"]);state["guardian_mythic_pity"]=tier==4?0:Math.Min(79,myth+1);state["guardian_legendary_pity"]=tier>=3?0:Math.Min(29,legend+1);
            var result=StateCommandResult.Success((string)profile["name"]+" · "+profile["tier"]+" · "+(free?"첫 무료 소환":"젬 -80"));
            result.Details=new JObject{{"id",id},{"name",profile["name"].DeepClone()},{"tier",profile["tier"].DeepClone()},{"new",first},{"copies",copies},{"free",free}};return result;
        });
        public StateCommandResult SummonHero(System.Random random)=>SummonHero((low,high)=>random.Next(low,high+1));
        internal StateCommandResult SummonHero(Func<int,int,int> random)=>Commit(state=>
        {
            var roster=catalog.HeroIds.Where(id=>ValidHero(state,id)).ToArray();if(roster.Length==0)return StateCommandResult.Fail("진영을 먼저 선택하세요.");
            long gems=Integer(state["wallet_gems"],0,0,CurrencyCap);if(gems<100)return StateCommandResult.Fail("영웅 소환에는 젬 100개가 필요합니다.");
            int index=random(0,roster.Length-1);if(index<0||index>=roster.Length)throw new ArgumentOutOfRangeException(nameof(random));string id=roster[index];int pity=(int)Integer(state["summon_pity"],0,0,9)+1,shards=pity>=10?30:12;
            state["wallet_gems"]=gems-100;state["summon_pity"]=pity>=10?0:pity;AddCurrency(Map(state,"hero_shards"),id,shards);Map(state,"codex_seen")[id]=true;
            var name=catalog.Hero(id)["name"];var result=StateCommandResult.Success((string)name+" · 영웅 조각 +"+shards+" · 젬 -100");result.Details=new JObject{{"hero_id",id},{"name",name},{"shards",shards}};return result;
        });
        public (int level,int xp,int evolution) PetProgress()
        {
            var entry=(data["pet_progress"] as JObject)?[Faction] as JObject;int level=(int)Integer(entry?["level"],1,1,100);
            return (level,level>=100?0:(int)Integer(entry?["xp"],0,0,100000000),level>=10?2:level>=5?1:0);
        }
        static int GrantPetXp(JObject state,int amount)
        {
            if(amount<=0)return 0;string faction=(string)state["selected_faction"];if(faction!="aurelia"&&faction!="noxfera")return 0;
            var progress=Entry(state,"pet_progress",faction);int level=(int)Integer(progress["level"],1,1,100),xp=level>=100?0:(int)Integer(progress["xp"],0,0,100000000);xp+=Math.Min(amount,100000000);
            while(level<100&&xp>=60+(level-1)*35){xp-=60+(level-1)*35;level++;}
            progress["level"]=level;progress["xp"]=level>=100?0:xp;progress["evolution"]=level>=10?2:level>=5?1:0;return level;
        }
        public StateCommandResult AwardPetXp(int amount)=>Commit(state=>GrantPetXp(state,amount)>0?StateCommandResult.Success("수호신 경험치 +"+Math.Min(amount,100000000)):StateCommandResult.Fail("수호신 경험치가 없습니다."));
    }
}
