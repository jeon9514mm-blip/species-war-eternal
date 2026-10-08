using System;
using System.IO;
using System.Linq;
using Newtonsoft.Json.Linq;

namespace Eternal.UnityMigration.Editor
{
    public static class AutoEquipmentVerification
    {
        public static JObject Verify()
        {
            var fixture=JObject.Parse(File.ReadAllText("Assets/Game/Editor/Fixtures/auto-equipment-fixtures.json"));var catalog=new OriginalCombatCatalog(OriginalCatalog.Required("hero-catalog").text);
            int comparisons=0,gains=0,recommendations=0;
            foreach(JObject row in fixture["cases"])
            {
                int saves=0;var state=new GameStateCommands(catalog,(JObject)row["before"],_=>{saves++;return true;});string before=state.Snapshot().ToString();
                if((string)row["type"]=="gain")
                {
                    int gain=state.AutomaticEquipmentGain((JObject)row["item"],(string)row["hero"]);
                    if(gain!=(int)row["gain"])throw new InvalidOperationException("Original automatic equipment gain differs: "+row["hero"]+" "+row["item"]+" = "+gain+" expected "+row["gain"]);gains++;comparisons++;
                }
                else
                {
                    var items=state.Inventory();for(int i=0;i<items.Count;i++)
                    {if(state.RecommendedEquipmentTarget(items[i])!=(string)row["targets"][i])throw new InvalidOperationException("Original automatic equipment target changed.");comparisons++;}
                }
                if(state.Snapshot().ToString()!=before||saves!=0)throw new InvalidOperationException("Equipment recommendation query mutated or saved player state.");comparisons+=2;
                if((string)row["type"]!="recommend")continue;
                var result=state.RecommendEquip();if(!result.Ok||saves!=(int)row["save_count"])throw new InvalidOperationException("Equipment recommendations did not use one save image.");comparisons+=2;
                var actual=state.Snapshot();var expected=(JObject)row["after"];
                foreach(var p in expected.Properties())
                {if(LegacySaveCodec.Canonical(actual[p.Name])!=LegacySaveCodec.Canonical(p.Value))throw new InvalidOperationException("Original recommend equipment changed "+p.Name+": "+actual[p.Name]+" expected "+p.Value);comparisons++;}
                if(((JArray)actual["loot_inventory"]).Count!=((JArray)row["before"]["loot_inventory"]).Count||state.WalletGold!=(long)row["before"]["wallet_gold"])throw new InvalidOperationException("Automatic equipment changed bag capacity or wallet.");comparisons+=2;recommendations++;
            }
            var report=new JObject{{"passed",true},{"comparisons",comparisons},{"production_gain_cases",gains},{"production_full_recommendation_cases",recommendations},{"set_bonuses_and_protected_items_preserved",true},{"read_only_queries",true},{"one_save_per_recommendation",true},{"note","Healthy original snapshots and canonical party order; workshop/market, corruption variants and native button input are not verified here."}};
            File.WriteAllText("../checks/unity-migration-2026-10-08/auto-equipment.json",report.ToString());return report;
        }
    }
}
