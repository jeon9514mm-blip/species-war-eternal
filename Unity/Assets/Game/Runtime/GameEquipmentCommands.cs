using System;
using System.Collections.Generic;
using System.Linq;
using Newtonsoft.Json.Linq;

namespace Eternal.UnityMigration
{
    public sealed partial class GameStateCommands
    {
        static JObject SlotsMap(JObject state,string key,string hero,JObject defaults)
        {var map=Map(state,key);if(map[hero] is JObject found)return found;var entry=(JObject)defaults.DeepClone();map[hero]=entry;return entry;}
        static JObject Levels(JObject state,string hero)
        {
            var levels=SlotsMap(state,"hero_equipment",hero,new JObject{{"weapon",1},{"armor",1},{"accessory",1}});
            foreach(string slot in OriginalEquipmentRules.Slots)levels[slot]=Integer(levels[slot],1,1,10);return levels;
        }
        static JObject RaritiesMap(JObject state,string hero)
        {
            var rarities=SlotsMap(state,"hero_equipment_rarity",hero,new JObject{{"weapon","일반"},{"armor","일반"},{"accessory","일반"}});
            foreach(string slot in OriginalEquipmentRules.Slots)if(rarities[slot]?.Type!=JTokenType.String||!OriginalEquipmentRules.Rarities.Contains((string)rarities[slot]))rarities[slot]="일반";
            return rarities;
        }
        static JObject NamesMap(JObject state,string hero)
        {
            var names=SlotsMap(state,"hero_equipment_names",hero,new JObject{{"weapon","초보자의 검"},{"armor","초보자의 가죽갑옷"},{"accessory","빛바랜 부적"}});
            foreach(string slot in OriginalEquipmentRules.Slots)if(names[slot]==null)names[slot]="초보자의 "+(slot=="weapon"?"무기":slot=="armor"?"방어구":"장신구");
            return names;
        }
        static JObject SetsMap(JObject state,string hero)
        {
            var sets=SlotsMap(state,"hero_equipment_sets",hero,new JObject{{"weapon","초보자"},{"armor","초보자"},{"accessory","초보자"}});
            foreach(string slot in OriginalEquipmentRules.Slots)if(sets[slot]==null)sets[slot]="초보자";return sets;
        }
        static JObject Equipped(JObject state,string hero,string slot)
        {
            var entries=Entry(state,"hero_equipment_items",hero);
            var item=entries[slot] is JObject saved?(JObject)saved.DeepClone():new JObject();
            if(item.Count==0)item=new JObject{{"id","legacy_equipped_"+hero+"_"+slot},{"origin","legacy"},{"bound",true}};
            item["slot"]=slot;item["level"]=Levels(state,hero)[slot].DeepClone();item["rarity"]=RaritiesMap(state,hero)[slot].DeepClone();
            item["name"]=NamesMap(state,hero)[slot].DeepClone();item["set"]=SetsMap(state,hero)[slot].DeepClone();item["bound"]=true;
            item=OriginalEquipmentRules.Normalize(item);entries[slot]=item.DeepClone();return item;
        }
        public JObject EquippedItem(string hero,string slot)=>!ValidHero(data,hero)||!OriginalEquipmentRules.Slots.Contains(slot)?new JObject():Equipped(Snapshot(),hero,slot);
        public IReadOnlyList<JObject> Inventory()
        {var result=new List<JObject>();if(data["loot_inventory"] is JArray inventory)foreach(var token in inventory)if(token is JObject item)result.Add(OriginalEquipmentRules.Normalize(item));return result;}
        static JArray Bag(JObject state){if(state["loot_inventory"] is JArray inventory)return inventory;inventory=new JArray();state["loot_inventory"]=inventory;return inventory;}
        static int ItemIndex(JArray inventory,string id){for(int i=0;i<inventory.Count;i++)if(inventory[i] is JObject item&&item["id"]?.Type==JTokenType.String&&(string)item["id"]==id)return i;return -1;}
        bool RoleMatches(JObject item,string hero)
        {
            string role=(string)item["hunt_role"]??"";if(role.Length==0)return true;string heroRole=(string)catalog.Hero(hero)["role_group"];
            return role=="dealer"&&heroRole=="딜러"||role=="defender"&&heroRole=="탱커"||role=="support"&&(heroRole=="서포터"||heroRole=="컨트롤러");
        }
        int GearPower(JObject state,string hero)
        {
            var levels=Levels(state,hero);var rarities=RaritiesMap(state,hero);double power=0;
            foreach(string slot in OriginalEquipmentRules.Slots)power+=(int)levels[slot]*OriginalEquipmentRules.SlotBase(slot)*OriginalEquipmentRules.RarityMultiplier((string)rarities[slot]);
            return (int)power;
        }
        public int EquipmentPower(string hero)=>ValidHero(data,hero)?GearPower(Snapshot(),hero):0;
        static JObject GearProfile(JObject state,string hero,JObject replacementSets=null)
        {
            var profile=OriginalEquipmentRules.SetProfile(replacementSets??SetsMap(state,hero));
            var options=OriginalEquipmentRules.AffixProfile(OriginalEquipmentRules.Slots.Select(slot=>Equipped(state,hero,slot)));
            profile["attack_mult"]=(double)profile["attack_mult"]*(1+(double)options["attack_pct"]/100);
            profile["hp_mult"]=(double)profile["hp_mult"]*(1+(double)options["hp_pct"]/100);
            profile["defense_bonus"]=(int)profile["defense_bonus"]+(int)options["defense"];
            profile["haste_pct"]=Math.Min(18,(double)profile["haste_pct"]+(double)options["haste_pct"]);
            profile["ultimate_pct"]=Math.Min(26,(double)profile["ultimate_pct"]+(double)options["ultimate_pct"]);return profile;
        }
        public JObject EquipmentProfile(string hero)=>ValidHero(data,hero)?GearProfile(Snapshot(),hero):OriginalEquipmentRules.SetProfile(new JObject());
        public StateCommandResult EquipGear(string itemId,string hero)=>Commit(state=>
        {
            var bag=Bag(state);int index=ItemIndex(bag,itemId);
            if(index<0||!ValidHero(state,hero))return StateCommandResult.Fail("장비나 영웅을 다시 선택해 주세요.");
            var item=OriginalEquipmentRules.Normalize(bag[index] as JObject);
            if(item.Count==0||(string)item["item_type"]!="equipment"||!RoleMatches(item,hero))return StateCommandResult.Fail("현재 영웅에게 장착할 수 없는 물품입니다.");
            if(((JObject)item["proposal"]).Count>0)return StateCommandResult.Fail("조율 후보를 선택하거나 포기한 뒤 장착하세요.");
            string slot=(string)item["slot"];var old=Equipped(state,hero,slot);item["bound"]=true;
            Entry(state,"hero_equipment_items",hero)[slot]=item;Levels(state,hero)[slot]=item["level"].DeepClone();RaritiesMap(state,hero)[slot]=item["rarity"].DeepClone();
            NamesMap(state,hero)[slot]=item["name"].DeepClone();SetsMap(state,hero)[slot]=item["set"].DeepClone();bag[index]=old;
            return StateCommandResult.Success("장비를 장착했습니다.");
        });
        public StateCommandResult EnhanceGear(string itemId,string hero="",string slot="")=>Commit(state=>
        {
            bool equipped=hero.Length>0;var bag=Bag(state);int index=equipped?-1:ItemIndex(bag,itemId);
            if(equipped&&(!ValidHero(state,hero)||!OriginalEquipmentRules.Slots.Contains(slot))||!equipped&&index<0)return StateCommandResult.Fail("장비가 이동했습니다. 다시 선택해 주세요.");
            var item=equipped?Equipped(state,hero,slot):OriginalEquipmentRules.Normalize(bag[index] as JObject);
            if(item.Count==0||(string)item["item_type"]!="equipment"||equipped&&itemId.Length>0&&(string)item["id"]!=itemId)return StateCommandResult.Fail("장비를 다시 선택해 주세요.");
            int level=(int)item["level"];if(level>=10)return StateCommandResult.Fail("이미 최대 강화 단계(+10)입니다.");
            int cost=LegacyGrowthEconomy.EquipmentCost((string)item["slot"],level);long gold=Integer(state["wallet_gold"],0,0,CurrencyCap);
            if(gold<cost)return StateCommandResult.Fail("강화 골드가 부족합니다.");
            item["level"]=level+1;item["power"]=(int)((level+1)*OriginalEquipmentRules.SlotBase((string)item["slot"])*OriginalEquipmentRules.RarityMultiplier((string)item["rarity"]));
            if(equipped){Levels(state,hero)[slot]=level+1;Entry(state,"hero_equipment_items",hero)[slot]=item;}else bag[index]=item;
            state["wallet_gold"]=gold-cost;return StateCommandResult.Success("장비를 +"+(level+1)+"로 강화했습니다.",-cost);
        });
        public StateCommandResult DecomposeGear(string itemId,bool confirmed=false)=>Commit(state=>
        {
            var bag=Bag(state);int index=ItemIndex(bag,itemId);if(index<0)return StateCommandResult.Fail("장비가 이동했습니다. 다시 선택해 주세요.");
            var item=OriginalEquipmentRules.Normalize(bag[index] as JObject);
            if(item.Count==0||(string)item["item_type"]!="equipment")return StateCommandResult.Fail("옵션 결정은 보관하거나 이식해 주세요.");
            if((bool)item["locked"]||((JObject)item["proposal"]).Count>0)return StateCommandResult.Fail("잠금과 진행 중인 옵션 선택을 확인하세요.");
            if(OriginalEquipmentRules.Protected(item)&&!confirmed)return StateCommandResult.Fail("옵션·레이드 장비의 분해 선택을 확인하세요.");
            int gold=OriginalEquipmentRules.SalvageValue(item);AddCurrency(state,"wallet_gold",gold);bag.RemoveAt(index);return StateCommandResult.Success("장비를 분해했습니다.",gold);
        });
        public StateCommandResult ToggleGearLock(string itemId)=>Commit(state=>
        {
            var bag=Bag(state);int index=ItemIndex(bag,itemId);if(index<0)return StateCommandResult.Fail("장비를 다시 선택해 주세요.");
            var item=OriginalEquipmentRules.Normalize(bag[index] as JObject);if(item.Count==0)return StateCommandResult.Fail("장비를 확인하세요.");
            item["locked"]=!(bool)item["locked"];bag[index]=item;return StateCommandResult.Success((bool)item["locked"]?"장비를 잠갔습니다.":"장비 잠금을 해제했습니다.");
        });
    }
}
