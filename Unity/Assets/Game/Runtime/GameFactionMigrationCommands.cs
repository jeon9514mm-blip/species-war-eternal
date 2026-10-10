using System;
using System.Collections.Generic;
using System.Linq;
using Newtonsoft.Json.Linq;
using L=Eternal.UnityMigration.LegacyFeatureCatalog;

namespace Eternal.UnityMigration
{
    public sealed partial class GameStateCommands
    {
        // One account retains global currency/progression. Faction-specific
        // territory, march, party and presets are banked in the original schema.
        public StateCommandResult SwitchAccountFaction(string target)=>Commit(state=>
        {
            if(target!="aurelia"&&target!="noxfera")return StateCommandResult.Fail("진영을 확인하세요.");
            if(target==Faction)return StateCommandResult.Success("현재 진영입니다.");
            if(state["unity_challenge_active"] is JObject)return StateCommandResult.Fail("도전을 먼저 종료하세요.");
            string previous=Faction;var worlds=Map(state,"faction_world_snapshots");
            var old=new LegacyWorldWar(state,previous,L.Now);
            worlds[previous]=new JObject{{"season_number",old.Season["season_number"]??1},{"war",old.State.DeepClone()},{"march",old.March.DeepClone()},{"conflict",old.Conflict.DeepClone()}};
            var parties=Map(state,"unity_faction_parties");parties[previous]=state["deployed_hero_ids"]?.DeepClone()??new JArray();
            Map(state,"faction_party_presets")[previous]=state["party_presets"]?.DeepClone()??new JArray(new JArray(),new JArray(),new JArray());
            Map(state,"unity_faction_preset_banks")[previous]=state["unity_party_presets"]?.DeepClone()??new JObject();
            state["unity_account_origin_faction"]??=previous;state["unity_linked_factions"]=true;state["selected_faction"]=target;
            var bank=L.Object(worlds[target]);long season=L.N(old.Season["season_number"],1);
            if(bank.Count>0&&L.N(bank["season_number"],season)>=season)
            {state["faction_war"]=L.Object(bank["war"]).DeepClone();state["faction_march"]=L.Object(bank["march"]).DeepClone();state["faction_conflict"]=L.Object(bank["conflict"]).DeepClone();}
            else
            {long honor=L.N(bank["war"]?["campaign_honor"]);state["faction_war"]=new JObject();state["faction_march"]=new JObject();state["faction_conflict"]=new JObject();var fresh=new LegacyWorldWar(state,target,L.Now);fresh.State["campaign_honor"]=honor;}
            new LegacyWorldWar(state,target,L.Now);
            var party=L.Array(parties[target]).Values<string>().Where(id=>id!=null&&heroFactions.GetValueOrDefault(id)==target).Distinct().Take(10).ToArray();
            if(party.Length==0)party=catalog.HeroIds.Where(id=>heroFactions[id]==target).Take(10).ToArray();
            state["deployed_hero_ids"]=new JArray(party);state["unity_party_presets"]=L.Object(state["unity_faction_preset_banks"]?[target]).DeepClone();
            state["party_presets"]=L.Array(state["faction_party_presets"]?[target]).DeepClone();state.Remove("unity_next_party");
            foreach(string id in catalog.HeroIds.Where(id=>heroFactions[id]==target))Progress(state,id);
            return StateCommandResult.Success((target=="aurelia"?"아우렐리아":"녹스페라")+" · 같은 계정의 진영 전환");
        });
    }
}
