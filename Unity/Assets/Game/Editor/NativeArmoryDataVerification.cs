using System;
using System.IO;
using System.Linq;
using Newtonsoft.Json.Linq;
using UnityEditor;
using UnityEngine;
namespace Eternal.UnityMigration.Editor
{
    public static class NativeArmoryDataVerification
    {
        static bool all;
        static JArray checks;
        static void Check(string name,bool ok){checks.Add(new JObject{{"name",name},{"passed",ok}});all&=ok;if(!ok)Debug.LogError("ROYAL_ARMORY_CHECK_FAILED: "+name);}
        static JObject Gear(string id,string slot,int level=5,string rarity="희귀")=>OriginalEquipmentRules.Normalize(new JObject{{"id",id},{"slot",slot},{"level",level},{"rarity",rarity},{"name","왕립 "+NativeEquipmentLayout.Label(slot)},{"set","새벽의 맹약"},{"origin","raid"}});
        static OriginalCombatCatalog Catalog()=>new OriginalCombatCatalog(OriginalCatalog.Required("hero-catalog").text);
        static void Core()
        {
            var catalog=Catalog();var payload=NativePlayerSession.NewPayload(catalog,"aurelia");
            var bag=(JArray)payload["loot_inventory"];int n=0;
            foreach(string position in NativeEquipmentLayout.Positions)bag.Add(Gear("verify_"+n++,NativeEquipmentLayout.ItemSlot(position)));
            JObject stored=null;var state=new GameStateCommands(catalog,payload,s=>{stored=(JObject)s.DeepClone();return true;});string hero="leonhardt";
            Check("legacy three records survive; seven added positions start empty",NativeEquipmentLayout.Positions.Count(p=>state.EquippedItem(hero,p).Count>0)==3&&(string)state.EquippedItem(hero,"accessory")["id"]=="legacy_equipped_leonhardt_accessory");
            int basePower=state.EquipmentPower(hero);n=0;
            foreach(string position in NativeEquipmentLayout.Positions)Check("real equipment command: "+position,state.EquipGear("verify_"+n++,hero,position).Ok);
            Check("ten equipped records are unique; ring positions share a type, not an item",NativeEquipmentLayout.Positions.Select(p=>(string)state.EquippedItem(hero,p)["id"]).Distinct().Count()==10&&(string)state.EquippedItem(hero,"ring1")["slot"]=="ring"&&(string)state.EquippedItem(hero,"ring2")["slot"]=="ring");
            Check("empty positions consume bag item without adding fake starter items",state.Inventory().Count==3&&state.Inventory().All(i=>((string)i["id"]).StartsWith("legacy_equipped_")));
            Check("ten gear pieces contribute to real combat profile",state.EquipmentPower(hero)>basePower&&state.CombatProfile(hero).Count>0);
            var saved=(JObject)stored.DeepClone();saved["wallet_gold"]=100000;state=new GameStateCommands(catalog,saved,s=>{stored=(JObject)s.DeepClone();return true;});
            int before=(int)state.EquippedItem(hero,"helmet")["level"];
            Check("new positions can enhance and persist",state.EnhanceGear("verify_1",hero,"helmet").Ok&&(int)state.EquippedItem(hero,"helmet")["level"]==before+1);
            var restored=new GameStateCommands(catalog,NativePlayerSession.ImportPayload(catalog,stored),_=>true);
            Check("expanded loadout survives legacy-compatible save import",NativeEquipmentLayout.Positions.All(p=>JToken.DeepEquals(state.EquippedItem(hero,p),restored.EquippedItem(hero,p))));
            Check("ten-slot combat preset includes both rings and empty-capable slots",state.SaveCombatPreset(0).Ok&&((JObject)state.CombatPreset(0)["equipment"][hero]).Count==10&&state.ApplyCombatPreset(0,state.CombatPreset(0)).Ok);
            var autoPayload=NativePlayerSession.NewPayload(catalog,"aurelia");autoPayload["loot_inventory"]=new JArray(NativeEquipmentLayout.Positions.Select((p,i)=>Gear("auto_"+i,NativeEquipmentLayout.ItemSlot(p))));
            var auto=new GameStateCommands(catalog,autoPayload,_=>true);Check("hero automatic equip fills all ten real positions",auto.RecommendHeroEquip(hero).Ok&&NativeEquipmentLayout.Positions.All(p=>((string)auto.EquippedItem(hero,p)["id"]).StartsWith("auto_")));
            var wrong=(JObject)autoPayload.DeepClone();var wrongState=new GameStateCommands(catalog,wrong,_=>true);var snapshot=wrongState.Snapshot();
            var preview=wrongState.CompareEquipment("auto_1",hero,"helmet");
            Check("comparison shows real before/after stats without moving items or saving",preview.Count>0&&(int)preview["after"]["hp"]>=(int)preview["before"]["hp"]&&JToken.DeepEquals(snapshot,wrongState.Snapshot()));
            Check("wrong part is rejected without deleting or moving items",!wrongState.EquipGear("auto_1",hero,"ring1").Ok&&JToken.DeepEquals(snapshot,wrongState.Snapshot()));
            wrong["loot_inventory"]=new JArray(Gear("locked","helmet"));wrong["loot_inventory"][0]["locked"]=true;var locked=new GameStateCommands(catalog,wrong,_=>true);
            Check("automatic equip preserves locked equipment",locked.RecommendHeroEquip(hero).Ok&&locked.EquippedItem(hero,"helmet").Count==0&&locked.Inventory().Count==1);
            var drops=new GameStateCommands(catalog,NativePlayerSession.NewPayload(catalog,"aurelia"),_=>true);
            for(int pack=1;pack<=20;pack++)drops.SettleUnityPack(pack,0,0,20);
            var kinds=drops.Inventory().Concat(drops.UnityEquipmentMail()).Select(i=>(string)i["slot"]).Distinct().ToArray();
            Check("new parts are obtainable from normal native hunting rewards",NativeEquipmentLayout.ItemSlots.All(kinds.Contains));
            Check("new rewards remain within bag capacity",drops.Inventory().Count<=GameStateCommands.UnityBagCapacity);
        }
        public static void Run()
        {
            all=true;checks=new JArray();
            try{Core();}catch(Exception e){Check(e.ToString(),false);}
            var report=new JObject{{"passed",all},{"count",checks.Count},{"checks",checks}};
            string file=Path.GetFullPath(Path.Combine(Application.dataPath,"../../native-armory-data-report.json"));
            File.WriteAllText(file,report.ToString());Debug.Log("NATIVE_ARMORY_DATA_REPORT: "+all+" · "+checks.Count);
            EditorApplication.Exit(all?0:1);
        }
    }
}
