using System.Linq;
using Newtonsoft.Json.Linq;

namespace Eternal.UnityMigration
{
    // Explicitly isolated startup data for native UI/combat review. This is not
    // an imported player save and its store callback retains memory only.
    public static class ReviewStateFixture
    {
        public static JObject Create(OriginalCombatCatalog catalog)
        {
            var heroes=catalog.HeroIds.Where(id=>(string)catalog.Hero(id)["faction"]=="aurelia").Take(10).ToArray();var progress=new JObject();var shards=new JObject();
            foreach(string id in heroes){progress[id]=new JObject{{"level",20},{"xp",0}};shards[id]=40;}
            var bag=new JArray();
            string[] names={"개척자의 장검","강철 수호갑옷","월광의 부적","별숲의 활","달빛 수호검"};
            for(int i=0;i<5;i++)bag.Add(OriginalEquipmentRules.Normalize(new JObject{{"id","native_review_gear_"+i},{"slot",OriginalEquipmentRules.Slots[i%3]},{"level",3+i},{"rarity",i==4?"전설":"희귀"},{"set",i==1?"강철":i==2?"월광":"개척자"},{"name",names[i]},{"origin",i==4?"raid":"hunt"},{"hunt_role",i==3?"dealer":""}}));
            return new JObject{{"save_version",LegacySaveCodec.Version},{"selected_faction","aurelia"},{"formation_id","balanced"},{"deployed_hero_ids",new JArray(heroes)},{"hero_progress",progress},{"hero_shards",shards},{"wallet_gold",10000},{"wallet_gems",100},{"wallet_xp",0},{"unclaimed_gold",500},{"unclaimed_xp",250},{"idle_chest_gold",0},{"idle_chest_xp",0},{"loot_inventory",bag},{"guardian_equipped","lumi"},{"guardian_collection",new JObject{{"lumi",new JObject{{"copies",1}}}}},{"native_review_fixture",true}};
        }
    }
}
