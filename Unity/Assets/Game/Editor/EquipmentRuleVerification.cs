using System;
using System.Collections.Generic;
using System.IO;
using Newtonsoft.Json.Linq;

namespace Eternal.UnityMigration.Editor
{
    public static class EquipmentRuleVerification
    {
        public static JObject Verify()
        {
            var oracle=JObject.Parse(File.ReadAllText("Assets/Game/Editor/Fixtures/equipment-rule-fixtures.json"));
            var catalog=new OriginalCombatCatalog(OriginalCatalog.Required("hero-catalog").text);int comparisons=0;var counts=new Dictionary<string,int>();
            foreach(JObject row in oracle["cases"])
            {
                string type=(string)row["type"];counts[type]=counts.GetValueOrDefault(type)+1;JObject actual,expected;
                if(type=="normalize"){actual=OriginalEquipmentRules.Normalize((JObject)row["raw"]);expected=(JObject)row["expected"];}
                else if(type=="sets"){actual=OriginalEquipmentRules.SetProfile((JObject)row["raw"]);expected=(JObject)row["expected"];}
                else
                {
                    string command=(string)row["command"],item=(string)row["item"],hero=(string)row["hero"];
                    var before=(JObject)row["before"];string original=before.ToString();var state=new GameStateCommands(catalog,before,_=>true);
                    var result=command switch
                    {
                        "equip"=>state.EquipGear(item,hero),
                        "enhance"=>state.EnhanceGear(item),
                        "enhance_equipped"=>state.EnhanceGear(item,hero,(string)row["slot"]),
                        "decompose"=>state.DecomposeGear(item,true),
                        _=>throw new InvalidOperationException("Unknown equipment command fixture")
                    };
                    comparisons++;if(result.Ok!=(bool)row["ok"])throw new InvalidOperationException("Original equipment command guard changed: "+command+" "+item);
                    comparisons++;if(before.ToString()!=original)throw new InvalidOperationException("Equipment command mutated caller payload.");
                    actual=state.Snapshot();expected=(JObject)row["after"];
                }
                comparisons++;if(actual.Count!=expected.Count)throw new InvalidOperationException("Equipment fixture field count: "+type+" "+actual.Count+" != "+expected.Count);
                foreach(var p in expected.Properties())
                {
                    comparisons++;if(LegacySaveCodec.Canonical(actual[p.Name])!=LegacySaveCodec.Canonical(p.Value))
                        throw new InvalidOperationException("Equipment "+type+" "+row["command"]+" "+p.Name+": "+actual[p.Name]+" != "+p.Value);
                }
            }
            var report=new JObject{{"passed",true},{"comparisons",comparisons},{"production_cases",((JArray)oracle["cases"]).Count},{"types",JObject.FromObject(counts)},{"note","Production equipment normalization/set rules and selected actual commands with isolated healthy snapshots; workshop/market/auto-equip, native UI and all corrupt legacy variants remain incomplete."}};
            File.WriteAllText("../checks/unity-migration-2026-10-08/equipment-rules.json",report.ToString());return report;
        }
    }
}
