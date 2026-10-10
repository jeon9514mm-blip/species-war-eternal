using System;
using System.Linq;
using Newtonsoft.Json.Linq;
using L=Eternal.UnityMigration.LegacyFeatureCatalog;

namespace Eternal.UnityMigration
{
    public sealed partial class GameStateCommands
    {
        public long RaidCrystals=>L.N(data["raid_crystals"],0,CurrencyCap);
        public StateCommandResult Workshop(string itemId,string action,int index=-1,string family="",string hero="",string slot="",string crystalId="",JObject expectedOption=null)=>Commit(state=>
        {
            var bag=Bag(state);bool equipped=hero.Length>0;
            var raw=equipped?ValidHero(state,hero)&&OriginalEquipmentRules.Slots.Contains(slot)?Equipped(state,hero,slot):null:bag.OfType<JObject>().FirstOrDefault(i=>(string)i["id"]==itemId);
            if(raw==null||equipped&&(string)raw["id"]!=itemId)return StateCommandResult.Fail("장비가 이동했습니다. 다시 선택하세요.");var item=OriginalEquipmentRules.Normalize(raw);if(item.Count==0||(string)item["item_type"]!="equipment")return StateCommandResult.Fail("장비에서 공방을 이용하세요.");
            var options=L.Array(item["affixes"]);var proposal=L.Object(item["proposal"]);long balance=L.N(state["raid_crystals"],0,CurrencyCap),cost=0;
            if(action=="preview")
            {
                string[] choices=family=="assault"?new[]{"attack_pct","ultimate_pct"}:family=="guard"?new[]{"hp_pct","defense"}:family=="flow"?new[]{"haste_pct","ultimate_pct"}:Array.Empty<string>();choices=choices.Where(k=>!options.Any(a=>(string)a["stat"]==k)).ToArray();cost=12+8*options.Count;
                if(choices.Length==0||proposal.Count>0||options.Count>=OriginalEquipmentRules.OptionCapacity(item))return StateCommandResult.Fail("옵션 계열·빈칸·저장된 후보를 확인하세요.");if(balance<cost)return StateCommandResult.Fail("레이드 정수가 부족합니다.");
                string salt=(string)state["unity_loot_salt"]??Guid.NewGuid().ToString("N");state["unity_loot_salt"]=salt;long serial=L.N(state["unity_workshop_serial"],0,CurrencyCap-1)+1;state["unity_workshop_serial"]=serial;bool focused=L.N(item["focus"])>=3;var generated=new JArray();
                foreach(string stat in choices){int low=stat=="attack_pct"?2:stat=="hp_pct"?3:stat=="ultimate_pct"?2:1,high=stat=="attack_pct"?6:stat=="hp_pct"?8:stat=="ultimate_pct"?5:stat=="defense"?4:3;generated.Add(new JObject{{"stat",stat},{"value",focused?high:low+(int)(LootDraw(salt,"workshop/"+serial+"/"+itemId,generated.Count)*(high-low+1))}});}
                item["proposal"]=new JObject{{"family",family},{"options",generated},{"cost",cost}};if(focused)item["focus"]=0;
            }
            else if(action=="choose")
            {var choices=L.Array(proposal["options"]);if(index<0||index>=choices.Count||options.Count>=OriginalEquipmentRules.OptionCapacity(item))return StateCommandResult.Fail("유효한 후보를 선택하세요.");options.Add(choices[index].DeepClone());item["proposal"]=new JObject();}
            else if(action=="discard")
            {if(proposal.Count==0)return StateCommandResult.Fail("포기할 후보가 없습니다.");item["proposal"]=new JObject();}
            else if(action=="remove"||action=="extract")
            {
                if(proposal.Count>0||index<0||index>=options.Count||expectedOption!=null&&!JToken.DeepEquals(expectedOption,options[index]))return StateCommandResult.Fail("옵션이 변경되었습니다. 다시 선택하세요.");cost=action=="remove"?6:18;if(balance<cost)return StateCommandResult.Fail("레이드 정수가 부족합니다.");
                if(action=="extract")
                {
                    if(bag.Count>=UnityBagCapacity&&LootArray(state,"equipment_overflow").Count>=UnityMailCapacity)return StateCommandResult.Fail("가방과 보관함에 빈칸을 확보하세요.");var option=(JObject)options[index].DeepClone();bool traded=L.N(item["trade_count"])>=1||L.N(option["trade_count"])>=1;if(traded)option["trade_count"]=1;
                    var crystal=OriginalEquipmentRules.Normalize(new JObject{{"id","unity_crystal_"+Guid.NewGuid().ToString("N")},{"item_type","option_crystal"},{"slot","accessory"},{"stored_option",option},{"origin",item["origin"]},{"source_id",item["source_id"]},{"zone",item["zone"]},{"bound",traded},{"trade_count",traded?1:0}});StoreUnityLoot(state,crystal);
                }
                else item["focus"]=Math.Min(3,L.N(item["focus"])+1);options.RemoveAt(index);
            }
            else if(action=="apply")
            {
                var rawCrystal=bag.OfType<JObject>().FirstOrDefault(c=>(string)c["id"]==crystalId);var crystal=OriginalEquipmentRules.Normalize(rawCrystal);cost=8;
                if(rawCrystal==null||(string)crystal["item_type"]!="option_crystal"||L.Flag(crystal["locked"])||proposal.Count>0||options.Count>=OriginalEquipmentRules.OptionCapacity(item))return StateCommandResult.Fail("옵션 결정·잠금·빈칸을 확인하세요.");var option=(JObject)crystal["stored_option"].DeepClone();if(options.Any(a=>(string)a["stat"]==(string)option["stat"]))return StateCommandResult.Fail("같은 종류의 옵션은 중복 이식할 수 없습니다.");if(balance<cost)return StateCommandResult.Fail("레이드 정수가 부족합니다.");if(L.N(crystal["trade_count"])>=1)option["trade_count"]=1;options.Add(option);rawCrystal.Remove();
            }
            else return StateCommandResult.Fail("지원하지 않는 공방 작업");
            state["raid_crystals"]=balance-cost;if(equipped)Entry(state,"hero_equipment_items",hero)[slot]=item;else raw.Replace(item);return StateCommandResult.Success("공방 작업 저장 · 정수 -"+cost);
        });
    }
}
