using System;
using System.Linq;
using Newtonsoft.Json.Linq;
using L=Eternal.UnityMigration.LegacyFeatureCatalog;

namespace Eternal.UnityMigration
{
    public sealed partial class GameStateCommands
    {
        static JObject StageChest(int stage)
        {stage=Math.Clamp(stage,1,10000);double tier=stage<=25?stage:25+Math.Sqrt(stage-25);return new JObject{{"gold",250+(int)Math.Floor(tier*50)},{"xp",100+(int)Math.Floor(tier*25)},{"rations",40+(int)Math.Floor(tier*3)}};}
        int PartyPower()=>DeployedHeroes().Sum(id=>{var p=CombatProfile(id);return (int)(L.N(p["max_hp"])*.12+L.N(p["attack"])*4+L.N(p["defense"])*2);});
        public StateCommandResult CalculateOffline(long now=0)=>Commit(state=>
        {
            now=now>0?now:L.Now;long previous=L.N(state["last_idle_timestamp"],0,long.MaxValue),elapsed=previous>0?Math.Clamp(now-previous,0,28800):0;state["last_idle_timestamp"]=Math.Max(now,previous);
            if(elapsed<5||DeployedHeroes().Count==0)return StateCommandResult.Success("오프라인 기록 확인");
            string zone="gray_meadow";var region=HuntingSimulation.Canonical["zones"][zone];int difficulty=(int)L.N(region["difficulty"],1,3),size=DeployedHeroes().Count;
            // New Unity movement has a different throughput signature; old Godot
            // samples remain preserved but use its conservative starter fallback.
            double ratio=Math.Max(.05,PartyPower()/(double)Math.Max(1,L.N(region["power"],100))),powerEfficiency=Math.Clamp(Math.Pow(ratio,.45),.42,1.38),partyEfficiency=Math.Clamp(.72+Math.Min(size,10)*.045,.76,1.08);
            double interval=Math.Max(Math.Clamp(6.2*(1+(difficulty-1)*.05)/(powerEfficiency*partyEfficiency),3.8,14),60/Math.Sqrt(Math.Clamp(size,1,10)));
            if(state["unity_hunt_productivity"]?[Faction+"/"+UnityZone] is JObject measured&&JToken.DeepEquals(measured["signature"],ProductivitySignature(state))&&PartyPower()>=L.N(measured["power"])*.9)
            {zone=UnityZone;region=HuntingSimulation.Canonical["zones"][zone];difficulty=(int)L.N(region["difficulty"],1,3);interval=Math.Max(interval,Math.Clamp(L.F(measured["seconds_per_pack"],interval),.1,3600));}
            int packs=(int)Math.Floor(elapsed/interval),rewardUnits=(int)Math.Floor(packs*.88),stage=(int)L.N(state["idle_stage"],1,10000),target=(int)Integer(state["idle_stage_target"],10,1,1000000),progress=(int)Integer(state["idle_stage_kills"],0,0,target-1)+packs,clearLimit=Math.Min(5,10000-stage),clears=Math.Min(clearLimit,progress/target);
            if(packs<=0)return StateCommandResult.Success("오프라인 기록 확인");
            long gold=(long)Math.Floor(rewardUnits*L.N(region["gold"])*(1+GuardianBonus("offline_gold"))),xp=(long)Math.Floor(rewardUnits*L.N(region["xp"])*(1+GuardianBonus("offline_xp"))),chestGold=0,chestXp=0,rations=rewardUnits*(4+difficulty*2);
            for(int i=0;i<clears;i++){var chest=StageChest(stage+i);chestGold+=L.N(chest["gold"]);chestXp+=L.N(chest["xp"]);rations+=L.N(chest["rations"]);}
            chestGold=(long)Math.Floor(chestGold*(1+GuardianBonus("offline_gold")));chestXp=(long)Math.Floor(chestXp*(1+GuardianBonus("offline_xp")));
            AddCurrency(state,"unclaimed_gold",gold);AddCurrency(state,"unclaimed_xp",xp);AddCurrency(state,"idle_chest_gold",chestGold);AddCurrency(state,"idle_chest_xp",chestXp);AddCurrency(state,"offline_pending_gold",gold);AddCurrency(state,"offline_pending_xp",xp);AddCurrency(state,"offline_pending_chest_gold",chestGold);AddCurrency(state,"offline_pending_chest_xp",chestXp);DistributeXp(state,(int)Math.Min(100000000,xp+chestXp));GrantPetXp(state,rewardUnits*(2+difficulty));
            if(L.Object(state["faction_war"]?["cells"]).Count>0)Map(state,"faction_war")["rations"]=Math.Min(1000000000,L.N(state["faction_war"]?["rations"])+rations);else AddCurrency(state,"unity_pending_rations",rations);
            state["idle_stage"]=stage+clears;state["idle_stage_kills"]=clears>=clearLimit?Math.Min(target-1,progress-clears*target):progress-clears*target;state["unity_pack_total"]=Math.Max(Integer(state["unity_pack_total"],0,0,int.MaxValue-1),(stage+clears-1)*5);
            int rolls=Math.Min(packs,Math.Min(32,10+difficulty*4+Math.Min(8,(int)elapsed/1800)));var pending=Map(state,"pending_equipment_rolls");pending[zone]=Math.Min(1000000000,L.N(pending[zone])+rolls);
            state["offline_reward_basis"]=zone+" · Unity 사냥 기록 또는 보수적 기본 사냥 기준";state["unity_last_offline"]=new JObject{{"seconds",elapsed},{"gold",gold+chestGold},{"xp",xp+chestXp},{"packs",packs},{"stages",clears},{"gear_rolls",rolls}};GoalRecord(state,"hunt_packs",packs,now);DeliverPendingOriginalLoot(state);
            return StateCommandResult.Success("오프라인 "+TimeSpan.FromSeconds(elapsed).ToString(@"hh\:mm\:ss")+" · 보상 보관 · 골드 "+(gold+chestGold),gold+chestGold,xp+chestXp);
        });
        JObject ProductivitySignature(JObject state)=>new(){{"heroes",new JArray(DeployedHeroes().OrderBy(id=>id,StringComparer.Ordinal))},{"formation",Formation},{"guardian",EquippedGuardian},{"equipment",state["hero_equipment_items"]?.DeepClone()??new JObject()},{"levels",state["hero_equipment"]?.DeepClone()??new JObject()},{"research",state["hero_skill_tree"]?.DeepClone()??new JObject()},{"skills",L.Flag(state["skill_auto"])},{"ultimates",L.Flag(state["ultimate_auto"])}};
        public StateCommandResult RecordHuntProductivity(double seconds,int packs)=>Commit(state=>
        {if(!double.IsFinite(seconds)||seconds<4||packs<12)return StateCommandResult.Fail("사냥 기록이 부족합니다.");Map(state,"unity_hunt_productivity")[Faction+"/"+UnityZone]=new JObject{{"signature",ProductivitySignature(state)},{"seconds_per_pack",Math.Clamp(seconds/packs,.1,3600)},{"power",PartyPower()},{"stage",1+UnityPacks/5}};return StateCommandResult.Success("사냥 생산성 기록");});
        public StateCommandResult StampIdleTime(long now=0)=>Commit(state=>{state["last_idle_timestamp"]=Math.Max(now>0?now:L.Now,L.N(state["last_idle_timestamp"],0,long.MaxValue));return StateCommandResult.Success("활동 시간 저장");});
        void DeliverPendingOriginalLoot(JObject state)
        {
            var pending=Map(state,"pending_equipment_rolls");string salt=(string)state["unity_loot_salt"]??Guid.NewGuid().ToString("N");state["unity_loot_salt"]=salt;
            foreach(string zone in new[]{"gray_meadow","forgotten_mine","moonrest_forest"})
            {
                int count=(int)Math.Min(32,L.N(pending[zone]));for(int i=0;i<count;i++)
                {if(Bag(state).Count>=UnityBagCapacity&&LootArray(state,"equipment_overflow").Count>=UnityMailCapacity)break;long serial=L.N(state["unity_pending_roll_serial"],0,CurrencyCap-1)+1;state["unity_pending_roll_serial"]=serial;int difficulty=(int)L.N(HuntingSimulation.Canonical["zones"][zone]["difficulty"],1,3);double roll=LootDraw(salt,"pending/"+serial,0);string rarity=UnityDropRarity(difficulty,roll,GuardianBonus("item_drop"));pending[zone]=Math.Max(0,L.N(pending[zone])-1);if(rarity.Length==0)continue;int slot=(int)(LootDraw(salt,"pending/"+serial,1)*3);var item=OriginalEquipmentRules.Normalize(new JObject{{"id","unity_pending_"+salt+"_"+serial},{"slot",OriginalEquipmentRules.Slots[slot]},{"rarity",rarity},{"level",1},{"name",(zone=="gray_meadow"?"초원":zone=="forgotten_mine"?"광맥":"달잠")+" 보급 "+SlotLabel(OriginalEquipmentRules.Slots[slot])},{"set",zone=="gray_meadow"?"개척자":zone=="forgotten_mine"?"강철":"월광"},{"origin","hunt"},{"source_id",zone}});StoreUnityLoot(state,item);}
            }
        }
        static string SlotLabel(string slot)=>NativeEquipmentLayout.Label(slot);
        void AwardRaidGear(JObject state,string zone,int difficulty,long clear,int performance)
        {
            AddCurrency(state,"raid_crystals",6+6*difficulty+Math.Clamp(performance,0,12));GrantPetXp(state,80+difficulty*30);var owned=Bag(state).OfType<JObject>().Concat(LootArray(state,"equipment_overflow").OfType<JObject>()).ToList();
            foreach(var hero in L.Object(state["hero_equipment_items"]).Properties())owned.AddRange(L.Object(hero.Value).Properties().Select(p=>L.Object(p.Value)));
            owned.AddRange(L.Array(state["gear_market_state"]?["accounts"]?["player_local"]?["deliveries"]).OfType<JObject>());owned.AddRange(L.Object(state["gear_market_state"]?["listings"]).Properties().Where(p=>(string)p.Value["seller_id"]=="player_local"&&(string)p.Value["status"]=="active").Select(p=>L.Object(p.Value["item"])));
            bool milestone=clear>0&&clear%5==0;var slots=NativeEquipmentLayout.ItemSlots.Where(slot=>!milestone||!owned.Any(i=>(string)i["origin"]=="raid"&&(string)i["source_id"]==zone&&(string)i["slot"]==slot)).ToArray();if(slots.Length==0)slots=NativeEquipmentLayout.ItemSlots;
            string salt=(string)state["unity_loot_salt"]??Guid.NewGuid().ToString("N");state["unity_loot_salt"]=salt;string nonce="raid/"+zone+"/"+clear;string slotId=slots[(int)(LootDraw(salt,nonce,0)*slots.Length)],rarity=milestone||LootDraw(salt,nonce,1)<.15+.05*difficulty?"전설":"희귀",set=zone=="gray_meadow"?"새벽의 맹약":zone=="forgotten_mine"?"철벽의 맹세":"월식의 추격";
            var item=OriginalEquipmentRules.Normalize(new JObject{{"id","unity_raid_"+salt+"_"+zone+"_"+clear},{"slot",slotId},{"rarity",rarity},{"level",1},{"name",set+" · "+SlotLabel(slotId)},{"set",set},{"origin","raid"},{"source_id",zone},{"zone",HuntingSimulation.Canonical["zones"][zone]["name"]}});StoreUnityLoot(state,item);state["unity_last_raid_loot"]=new JObject{{"item",item.DeepClone()},{"crystals",6+6*difficulty+Math.Clamp(performance,0,12)},{"milestone",milestone}};
        }
    }
}
