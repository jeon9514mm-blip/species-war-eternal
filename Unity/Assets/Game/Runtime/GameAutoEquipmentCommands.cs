using System;
using System.Collections.Generic;
using System.Linq;
using Newtonsoft.Json.Linq;

namespace Eternal.UnityMigration
{
    public sealed partial class GameStateCommands
    {
        int AutoGain(JObject state,JObject raw,string hero,bool explicitChoice=false)
        {
            if(!ValidHero(state,hero))return 0;var item=OriginalEquipmentRules.Normalize(raw);
            if(item.Count==0||!RoleMatches(item,hero)||(string)item["item_type"]!="equipment")return 0;string slot=BestEquipmentPosition(state,item,hero);if(slot.Length==0)return 0;
            var equipped=Equipped(state,hero,slot);
            if(!explicitChoice&&(OriginalEquipmentRules.Protected(item)||equipped.Count>0&&OriginalEquipmentRules.Protected(equipped)))return 0;
            if((bool)item["locked"]||((JObject)item["proposal"]).Count>0||equipped.Count>0&&((bool)equipped["locked"]||((JObject)equipped["proposal"]).Count>0))return 0;
            int current=equipped.Count>0?(int)equipped["power"]:0;
            int gain=(int)item["power"]-current;if(gain<=0)return 0;
            var oldSet=GearProfile(state,hero);var replacements=(JObject)SetsMap(state,hero).DeepClone();replacements[slot]=item["set"].DeepClone();var newSet=GearProfile(state,hero,replacements);
            if((double)newSet["hp_mult"]<(double)oldSet["hp_mult"]||(int)newSet["defense_bonus"]<(int)oldSet["defense_bonus"])return 0;
            int level=(int)Progress(state,hero)["level"];var tree=Tree(state,hero);int spent=(int)tree["offense"]+(int)tree["survival"]+(int)tree["utility"];
            int breakthrough=(int)Integer((state["hero_breakthrough"] as JObject)?[hero],0,0,5),power=140+(level-1)*35+GearPower(state,hero)+spent*22+breakthrough*55;
            return Math.Max(0,(int)((power+gain)*(double)newSet["attack_mult"]-power*(double)oldSet["attack_mult"]));
        }
        public int AutomaticEquipmentGain(JObject item,string hero)=>AutoGain(Snapshot(),item,hero);
        string BestEquipmentPosition(JObject state,JObject item,string hero)=>NativeEquipmentLayout.Matching((string)item["slot"]).Where(p=>{var old=Equipped(state,hero,p);return old.Count==0||!(bool)old["locked"]&&((JObject)old["proposal"]).Count==0;}).OrderBy(p=>(int?)Equipped(state,hero,p)["power"]??0).FirstOrDefault()??"";
        public string EquipmentPositionFor(JObject item,string hero)=>ValidHero(data,hero)?BestEquipmentPosition(Snapshot(),item,hero):"";
        public StateCommandResult RecommendHeroEquip(string hero)=>Commit(state=>
        {
            if(!ValidHero(state,hero))return StateCommandResult.Fail("영웅을 확인하세요.");
            int count=0;var bag=Bag(state);
            foreach(string itemId in bag.OfType<JObject>().OrderByDescending(i=>(int?)i["power"]??0).Select(i=>(string)i["id"]).ToArray())
            {int index=ItemIndex(bag,itemId);if(index>=0&&bag[index] is JObject item&&AutoGain(state,item,hero,true)>0&&EquipDraft(state,itemId,hero).Ok)count++;}
            return StateCommandResult.Success("자동장착 완료 · "+count+"개 교체 · 잠금·세트 보호");
        });
        IReadOnlyList<string> EquipmentParty(JObject state)
        {
            var ids=new List<string>();
            foreach(var token in state["deployed_hero_ids"] as JArray??new JArray())
            {if(token.Type==JTokenType.String&&ValidHero(state,(string)token)&&!ids.Contains((string)token)&&ids.Count<10)ids.Add((string)token);}
            return ids.Count>0?ids:catalog.HeroIds.Where(id=>ValidHero(state,id)).Take(3).ToArray();
        }
        string BestEquipmentTarget(JObject state,JObject item,IReadOnlyList<string> party,bool explicitChoice=false)
        {
            string best="";int bestGain=0;
            foreach(string id in party){int gain=AutoGain(state,item,id,explicitChoice);if(gain>bestGain){best=id;bestGain=gain;}}return best;
        }
        public string RecommendedEquipmentTarget(JObject item)
        {var state=Snapshot();return BestEquipmentTarget(state,item,EquipmentParty(state));}
        public StateCommandResult RecommendEquip()=>Commit(state=>
        {
            var party=EquipmentParty(state);var bag=Bag(state);
            if(party.Count==0||bag.Count==0)return StateCommandResult.Fail("추천장착할 영웅 또는 장비가 없습니다.");
            int count=0;
            // In-place exchange preserves bag capacity. A displaced item can
            // improve another hero, so repeat at most one pass per party member.
            for(int pass=0;pass<party.Count;pass++)
            {
                bool changed=false;
                for(int i=0;i<bag.Count;i++)
                {
                    if(bag[i] is not JObject item)continue;string hero=BestEquipmentTarget(state,item,party,true);
                    if(hero.Length==0||!EquipDraft(state,(string)item["id"],hero).Ok)continue;count++;changed=true;if(i>=bag.Count||bag[i] is JObject moved&&(string)moved["id"]!=(string)item["id"])i--;
                }
                if(!changed)break;
            }
            return StateCommandResult.Success("추천장착 완료 · "+count+"개 교체 · 세트 효과 보호");
        });
    }
}
