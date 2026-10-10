using System.Linq;
using Newtonsoft.Json.Linq;
using UnityEngine.UIElements;
using L=Eternal.UnityMigration.LegacyFeatureCatalog;

namespace Eternal.UnityMigration
{
    public sealed partial class HuntingMigrationReview
    {
        void ShowWorkshop(string id,string hero="",string slot="")
        {
            var item=hero.Length>0?ReviewState.EquippedItem(hero,slot):ReviewState.Inventory().FirstOrDefault(i=>(string)i["id"]==id);if(item==null||item.Count==0){ShowInventory();return;}
            PanelHeader("장비 공방 · "+item["name"]);var scroll=new ScrollView();scroll.style.flexGrow=1;modal.Add(scroll);Text(scroll,"레이드 정수 "+ReviewState.RaidCrystals+" · 옵션 "+L.Array(item["affixes"]).Count+" / "+OriginalEquipmentRules.OptionCapacity(item)+" · 집중도 "+item["focus"]+" / 3",14);GrowthNotice(scroll);
            var proposal=L.Object(item["proposal"]);
            if(proposal.Count>0)
            {int i=0;foreach(var option in L.Array(proposal["options"])){int index=i++;GrowthButton(scroll,option["stat"]+" +"+option["value"]+" 선택",()=>ReviewState.Workshop(id,"choose",index,hero:hero,slot:slot),()=>ShowWorkshop(id,hero,slot));}GrowthButton(scroll,"후보 포기 · 정수 반환 없음",()=>ReviewState.Workshop(id,"discard",hero:hero,slot:slot),()=>ShowWorkshop(id,hero,slot));}
            else
            {
                foreach(var family in new[]{("assault","공격"),("guard","생존"),("flow","흐름")}){string key=family.Item1;GrowthButton(scroll,family.Item2+" 후보 생성 · 정수 "+(12+8*L.Array(item["affixes"]).Count),()=>ReviewState.Workshop(id,"preview",family:key,hero:hero,slot:slot),()=>ShowWorkshop(id,hero,slot));}
                int i=0;foreach(var option in L.Array(item["affixes"]).OfType<JObject>()){int index=i++;var expected=(JObject)option.DeepClone();LegacySection(scroll,(string)option["stat"],"+"+option["value"]);GrowthButton(scroll,"삭제 · 정수 6 · 집중도 +1",()=>ReviewState.Workshop(id,"remove",index,hero:hero,slot:slot,expectedOption:expected),()=>ShowWorkshop(id,hero,slot));GrowthButton(scroll,"옵션 결정 추출 · 정수 18",()=>ReviewState.Workshop(id,"extract",index,hero:hero,slot:slot,expectedOption:expected),()=>ShowWorkshop(id,hero,slot));}
                foreach(var crystal in ReviewState.Inventory().Where(c=>(string)c["item_type"]=="option_crystal")){string crystalId=(string)crystal["id"];GrowthButton(scroll,"이식 · "+crystal["name"]+" · 정수 8",()=>ReviewState.Workshop(id,"apply",hero:hero,slot:slot,crystalId:crystalId),()=>ShowWorkshop(id,hero,slot));}
            }
        }
    }
}
