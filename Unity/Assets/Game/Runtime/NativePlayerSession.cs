using System;
using System.Linq;
using Newtonsoft.Json.Linq;

namespace Eternal.UnityMigration
{
    public sealed class NativePlayerSession
    {
        public readonly GameStateCommands State;
        public readonly NativeSessionStore Store;
        public NativePlayerSession(OriginalCombatCatalog catalog,JObject payload,NativeSessionStore store)
        {Store=store;State=new GameStateCommands(catalog,payload,Store.Write);}
        public static JObject ImportPayload(OriginalCombatCatalog catalog,JObject original)
        {
            string faction=(string)original["selected_faction"];
            if(faction!="aurelia"&&faction!="noxfera")throw new ArgumentException("Unknown faction.");
            var payload=(JObject)original.DeepClone();payload.Remove("native_review_fixture");payload.Remove("native_review_settled_pack");payload["unity_player_profile"]=true;payload["save_version"]=LegacySaveCodec.Version;
            if(payload["deployed_hero_ids"] is not JArray deployed||!deployed.Any(t=>t.Type==JTokenType.String&&catalog.HeroIds.Contains((string)t)&&(string)catalog.Hero((string)t)["faction"]==faction))
                payload["deployed_hero_ids"]=new JArray(catalog.HeroIds.Where(id=>(string)catalog.Hero(id)["faction"]==faction).Take(10));
            int stage=(int)GameStateCommands.Integer(payload["idle_stage"],1,1,1000000);payload["unity_pack_total"]=(stage-1)*5;
            string zone=(string)payload["current_zone_id"];payload["unity_hunt_zone"]=new[]{"gray_meadow","forgotten_mine","moonrest_forest"}.Contains(zone)?zone:"gray_meadow";
            return payload;
        }
        public static JObject NewPayload(OriginalCombatCatalog catalog,string faction)
        {
            var heroes=catalog.HeroIds.Where(id=>(string)catalog.Hero(id)["faction"]==faction).ToArray();
            if(heroes.Length!=15)throw new InvalidOperationException("Original faction roster missing.");
            var progress=new JObject();foreach(string id in heroes)progress[id]=new JObject{{"level",1},{"xp",0}};
            string guardian=faction=="aurelia"?"lumi":"umbra";
            return new JObject{{"save_version",LegacySaveCodec.Version},{"unity_player_profile",true},{"selected_faction",faction},{"formation_id","balanced"},{"deployed_hero_ids",new JArray(heroes.Take(10))},{"hero_progress",progress},{"hero_shards",new JObject()},{"wallet_gold",500},{"wallet_gems",100},{"wallet_xp",0},{"loot_inventory",new JArray()},{"guardian_equipped",guardian},{"guardian_collection",new JObject{{guardian,new JObject{{"copies",1}}}}},{"unity_pack_total",0},{"unity_hunt_zone","gray_meadow"}};
        }
    }
}
