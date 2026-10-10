using System;
using System.Collections.Generic;
using System.Linq;
using Newtonsoft.Json.Linq;
using L=Eternal.UnityMigration.LegacyFeatureCatalog;

namespace Eternal.UnityMigration
{
    public sealed partial class GameStateCommands
    {
        void NormalizeMigrationLinks()
        {
            if(!UnityPlayer)return;
            foreach(string flag in new[]{"skill_auto","ultimate_auto"})if(data[flag]?.Type!=JTokenType.Boolean)data[flag]=true;
            if(data["gear_auto_equip"]?.Type!=JTokenType.Boolean)data["gear_auto_equip"]=true;
            if(data["unity_party_presets"] is not JObject)
            {
                var converted=new JObject();var bank=L.Array(data["faction_party_presets"]?[Faction]);if(bank.Count==0)bank=L.Array(data["party_presets"]);
                for(int i=0;i<Math.Min(3,bank.Count);i++){var ids=L.Array(bank[i]).Values<string>().Where(id=>ValidHero(data,id)).Distinct().Take(10).ToArray();if(ids.Length>0)converted[i.ToString()]=new JObject{{"heroes",new JArray(ids)},{"formation",Formation}};}data["unity_party_presets"]=converted;
            }
        }
        public StateCommandResult SetCombatOptions(bool skillAuto,bool ultimateAuto,double battleSpeed)=>Commit(state=>
        {if(!double.IsFinite(battleSpeed)||!new[]{1d,2d,3d}.Contains(battleSpeed))return StateCommandResult.Fail("전투 배율을 확인하세요.");state["skill_auto"]=skillAuto;state["ultimate_auto"]=ultimateAuto;state["battle_speed"]=battleSpeed;return StateCommandResult.Success("자동 전투 설정 저장");});
        public bool HuntAuto=>data["unity_hunt_auto"]?.Type!=JTokenType.Boolean||(bool)data["unity_hunt_auto"];
        public StateCommandResult SetAutomationOption(string channel,bool enabled)=>Commit(state=>
        {
            string key=channel=="skills"?"skill_auto":channel=="ultimate"?"ultimate_auto":channel=="hunt"?"unity_hunt_auto":"";
            if(key.Length==0)return StateCommandResult.Fail("자동 전투 설정을 확인하세요.");state[key]=enabled;return StateCommandResult.Success("자동 전투 설정 저장");
        });
        public StateCommandResult SetLootOptions(bool automatic,string salvage)=>Commit(state=>{if(!OriginalEquipmentRules.Rarities.Contains(salvage))return StateCommandResult.Fail("분해 등급을 확인하세요.");state["gear_auto_equip"]=automatic;state["auto_salvage_min_rarity"]=salvage;return StateCommandResult.Success("장비 자동 설정 저장");});
        public JObject CombatPreset(int index)
        {var bank=L.Array(data["combat_presets"]?[Faction]);return index>=0&&index<3&&index<bank.Count?(JObject)L.Object(bank[index]).DeepClone():new JObject();}
        public StateCommandResult SaveCombatPreset(int index)=>Commit(state=>
        {
            if(index<0||index>2||DeployedHeroes().Count<1)return StateCommandResult.Fail("P1~P3과 편성을 선택하세요.");var ids=DeployedHeroes();var gear=new JObject();var used=new HashSet<string>();
            foreach(string id in ids){var slots=new JObject();foreach(string slot in NativeEquipmentLayout.Positions){var item=Equipped(state,id,slot);string key=(string)item["id"]??"";if(key.Length>0&&!used.Add(key))return StateCommandResult.Fail("중복 장비 ID");slots[slot]=key;}gear[id]=slots;}
            var presets=Map(state,"combat_presets");var bank=L.Array(presets[Faction]);while(bank.Count<3)bank.Add(new JObject());bank[index]=new JObject{{"schema",2},{"formation_id",Formation},{"heroes",new JArray(ids)},{"equipment",gear},{"guardian",EquippedGuardian},{"skill_auto",L.Flag(state["skill_auto"])},{"ultimate_auto",L.Flag(state["ultimate_auto"])}};presets[Faction]=bank;state["active_preset_index"]=index;return StateCommandResult.Success("통합 P"+(index+1)+" 저장 · 편성·10부위 장비·수호신·자동 스킬");
        });
        public StateCommandResult ApplyCombatPreset(int index,JObject expected)=>Commit(state=>
        {
            var saved=CombatPreset(index);if(saved.Count==0||expected==null||!JToken.DeepEquals(saved,expected))return StateCommandResult.Fail("프리셋이 비었거나 변경되었습니다.");var ids=L.Array(saved["heroes"]).Values<string>().ToArray();if(ids.Length<1||ids.Length>10||ids.Distinct().Count()!=ids.Length||ids.Any(id=>!ValidHero(state,id)))return StateCommandResult.Fail("영웅·진영 정보를 확인하세요.");string guardian=(string)saved["guardian"]??"",formation=(string)saved["formation_id"]??"balanced";if(FormationProfiles[formation]==null||guardian.Length>0&&state["guardian_collection"]?[guardian] is not JObject)return StateCommandResult.Fail("진형·보유 수호신을 확인하세요.");
            var bag=Bag(state);var all=new Dictionary<string,(JObject item,string hero,string slot)>();
            bool Add(JObject item,string hero,string slot){if(item.Count==0)return true;string key=(string)item["id"];return key!=null&&all.TryAdd(key,(item,hero,slot));}
            foreach(var item in bag.OfType<JObject>())if(!Add(item,"",""))return StateCommandResult.Fail("가방 장비 ID 중복");
            foreach(string id in catalog.HeroIds.Where(id=>ValidHero(state,id)))foreach(string slot in NativeEquipmentLayout.Positions)if(!Add(Equipped(state,id,slot),id,slot))return StateCommandResult.Fail("장착 장비 ID 중복");
            var positions=L.N(saved["schema"])>=2?NativeEquipmentLayout.Positions:OriginalEquipmentRules.Slots;
            var used=new HashSet<string>();var desired=new JObject();
            foreach(string id in ids)
            {var slots=new JObject();foreach(string slot in positions){string key=(string)saved["equipment"]?[id]?[slot];if(key==""&&!OriginalEquipmentRules.Slots.Contains(slot)){slots[slot]=new JObject();continue;}if(key==null||!used.Add(key)||!all.TryGetValue(key,out var owned)||owned.hero.Length>0&&!ids.Contains(owned.hero))return StateCommandResult.Fail("없거나 다른 영웅이 장착한 장비가 있습니다.");var item=OriginalEquipmentRules.Normalize(owned.item);if((string)item["item_type"]!="equipment"||!NativeEquipmentLayout.Fits((string)item["slot"],slot)||!RoleMatches(item,id)||L.Object(item["proposal"]).Count>0&&!(owned.hero==id&&owned.slot==slot))return StateCommandResult.Fail("장비 부위·역할·옵션 후보를 확인하세요.");item["bound"]=true;slots[slot]=item;}desired[id]=slots;}
            var nextBag=new JArray(bag.OfType<JObject>().Where(i=>!used.Contains((string)i["id"])).Select(i=>i.DeepClone()));
            foreach(string id in ids)foreach(string slot in positions){var old=Equipped(state,id,slot);if(old.Count>0&&!used.Contains((string)old["id"])){if(L.Object(old["proposal"]).Count>0)return StateCommandResult.Fail("교체할 장비의 옵션 후보를 먼저 결정하세요.");nextBag.Add(old);}}
            if(nextBag.Count>UnityBagCapacity)return StateCommandResult.Fail("교체 장비를 보관할 가방 공간이 부족합니다.");
            state["loot_inventory"]=nextBag;
            foreach(string id in ids)foreach(string slot in positions)WriteEquipped(state,id,slot,(JObject)desired[id][slot]);
            state["guardian_equipped"]=guardian;state["skill_auto"]=L.Flag(saved["skill_auto"]);state["ultimate_auto"]=L.Flag(saved["ultimate_auto"]);state["active_preset_index"]=index;state["unity_next_party"]=new JObject{{"heroes",new JArray(ids)},{"formation",formation}};
            return StateCommandResult.Success("통합 프리셋 적용 · 다음 무리부터 편성 변경");
        });
    }
}
