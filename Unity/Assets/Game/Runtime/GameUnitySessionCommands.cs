using System;
using System.Linq;
using Newtonsoft.Json.Linq;

namespace Eternal.UnityMigration
{
    public sealed partial class GameStateCommands
    {
        public bool UnityPlayer=>(bool?)data["unity_player_profile"]==true;
        public int UnityPacks=>(int)Integer(data["unity_pack_total"],0,0,int.MaxValue-1);
        public string UnityZone=>UnityPlayer?HuntStageWorld.Zone(1+UnityPacks/5):new[]{"gray_meadow","forgotten_mine","moonrest_forest"}.Contains((string)data["unity_hunt_zone"])?(string)data["unity_hunt_zone"]:"gray_meadow";
        public StateCommandResult SetUnityParty(string[] heroes,string formation)=>Commit(state=>
        {
            if(!UnityPlayer||heroes==null||heroes.Length<1||heroes.Length>10||heroes.Distinct().Count()!=heroes.Length||heroes.Any(id=>!ValidHero(state,id))||formation==null||FormationProfiles[formation]==null)return StateCommandResult.Fail("진영·영웅·진형을 확인하세요.");
            state["unity_next_party"]=new JObject{{"heroes",new JArray(heroes)},{"formation",formation}};return StateCommandResult.Success("다음 무리부터 새 편성을 적용합니다.");
        });
        public StateCommandResult SetUnityZone(string zone)=>Commit(state=>
        {
            return StateCommandResult.Fail("사냥터는 스테이지 구간에 따라 자동으로 변경됩니다.");
        });
        public StateCommandResult SettleUnityPack(int pack,long gold,int xp,int defeats=12)=>Commit(state=>
        {
            if(!UnityPlayer||HasDeferredUnityLoot||pack!=Integer(state["unity_pack_total"],0,0,int.MaxValue-1)+1||gold<0||gold>CurrencyCap||xp<0||xp>100000000||defeats<1||defeats>12)return StateCommandResult.Fail("중복되거나 잘못된 사냥 보상입니다.");
            // Award the defeated wave's theme, before stage/party advancement.
            string zone=HuntStageWorld.Zone(1+(pack-1)/5);
            var drops=AwardUnityHuntLoot(state,zone,pack,defeats);
            state["unity_pack_total"]=pack;AddCurrency(state,"wallet_gold",gold);AddCurrency(state,"wallet_xp",xp);int assigned=DistributeXp(state,xp);
            state["unity_hunt_zone"]=HuntStageWorld.Zone(1+pack/5);
            if(state["unity_next_party"] is JObject next&&next["heroes"] is JArray heroes)
            {state["deployed_hero_ids"]=heroes.DeepClone();state["formation_id"]=next["formation"]?.DeepClone()??new JValue("balanced");state.Remove("unity_next_party");state.Remove("unity_chain");}
            var result=StateCommandResult.Success("무리 격파 · 골드 +"+gold+" · 경험치 +"+assigned+(drops.Count>0?" · 장비 "+drops.Count+"개":""),gold,assigned);result.Details["drops"]=drops;return result;
        });
        public StateCommandResult SetUnityChain(ChainSkill[] entries,bool enabled)=>Commit(state=>
        {
            var deployed=DeployedHeroes();
            if(!UnityPlayer||entries==null||entries.Length<1||entries.Length>6||entries.Distinct().Count()!=entries.Length||entries.Any(s=>!deployed.Contains(s.Hero)||s.Slot!="a1"&&s.Slot!="a2"&&s.Slot!="ultimate"))return StateCommandResult.Fail("스킬 연계를 확인하세요.");
            state["unity_chain"]=new JArray(entries.Select(s=>new JObject{{"hero",s.Hero},{"slot",s.Slot}}));state["unity_chain_enabled"]=enabled;return StateCommandResult.Success("스킬 연계가 저장되었습니다.");
        });
        public StateCommandResult ReserveUnityRaid(string zone)=>Commit(state=>
        {
            if(!UnityPlayer||HasDeferredUnityLoot||zone==null||HuntingSimulation.Canonical["zones"][zone]==null)return StateCommandResult.Fail("레이드 지역과 장비 보관 공간을 확인하세요.");
            long attempt=Integer(state["unity_raid_attempt"],0,0,CurrencyCap-1)+1;state["unity_raid_attempt"]=attempt;
            state["unity_raid_active"]=new JObject{{"zone",zone},{"attempt",attempt}};
            var result=StateCommandResult.Success("레이드 도전");result.Details["attempt"]=attempt;return result;
        });
        public StateCommandResult SetUnityRaidChain(string zone,ChainSkill[] entries,bool enabled)=>Commit(state=>
        {
            var deployed=DeployedHeroes();
            if(!UnityPlayer||zone==null||!new[]{"gray_meadow","forgotten_mine","moonrest_forest"}.Contains(zone)||entries==null||entries.Length<1||entries.Length>6||entries.Distinct().Count()!=entries.Length||entries.Any(s=>!deployed.Contains(s.Hero)||s.Slot!="a1"&&s.Slot!="a2"&&s.Slot!="ultimate"))return StateCommandResult.Fail("레이드 스킬 연계를 확인하세요.");
            Map(state,"unity_raid_chains")[zone]=new JObject{{"enabled",enabled},{"entries",new JArray(entries.Select(s=>new JObject{{"hero",s.Hero},{"slot",s.Slot}}))}};
            return StateCommandResult.Success("이 지역의 레이드 연계가 저장되었습니다.");
        });
        public StateCommandResult SettleUnityRaid(string zone,long attempt)=>Commit(state=>
        {
            var active=state["unity_raid_active"] as JObject;
            if(!UnityPlayer||active==null||(string)active["zone"]!=zone||Integer(active["attempt"],0,0,CurrencyCap)!=attempt)return StateCommandResult.Fail("이미 처리했거나 유효하지 않은 레이드입니다.");
            var region=HuntingSimulation.Canonical["zones"][zone];long gold=20*Integer(region["gold"],0,0,CurrencyCap/20);int xp=10*(int)Integer(region["xp"],0,0,10000000);
            state.Remove("unity_raid_active");var wins=Map(state,"unity_raid_wins");wins[zone]=Integer(wins[zone],0,0,CurrencyCap-1)+1;
            AddCurrency(state,"wallet_gold",gold);AddCurrency(state,"wallet_xp",xp);int assigned=DistributeXp(state,xp);
            return StateCommandResult.Success("레이드 보상 · 골드 +"+gold+" · 영웅 경험치 +"+assigned,gold,assigned);
        });
    }
}
