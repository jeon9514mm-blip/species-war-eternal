using System;
using System.Linq;
using Newtonsoft.Json.Linq;
using UnityEngine;
using UnityEngine.UIElements;

namespace Eternal.UnityMigration
{
    public sealed partial class HuntingMigrationReview
    {
        string growthMessage="",growthSection="장비";
        bool GrowthAllowed=>Raid==null&&!ChallengeActive&&ReviewState.MutationError.Length==0;
        static string SlotName(string slot)=>NativeEquipmentLayout.Label(slot);
        void StateCommand(Func<StateCommandResult> command,Action refresh)
        {
            if(!GrowthAllowed){growthMessage=Raid!=null?"레이드를 마친 뒤 성장을 변경하세요.":ReviewState.MutationError;refresh();return;}
            var result=command();growthMessage=result.Message+(result.SavePending?" · 저장 대기":"");
            if(result.Ok)Simulation.RefreshHeroGrowth();PauseForSaveFailure();refresh();RefreshHud();
        }
        void GrowthNotice(VisualElement parent)
        {
            if(growthMessage.Length==0)return;var notice=Text(parent,growthMessage,13);notice.style.whiteSpace=WhiteSpace.Normal;notice.style.color=Moss;notice.style.marginTop=12;notice.style.marginBottom=8;
        }
        Button GrowthButton(VisualElement parent,string title,Func<StateCommandResult> command,Action refresh,bool allowed=true)
        {var b=Button(parent,title,()=>StateCommand(command,refresh));b.style.marginLeft=0;b.style.marginRight=6;b.SetEnabled(GrowthAllowed&&allowed);return b;}
        void ShowGrowth(string id)
        {
            ShowHeroShowcase(id);
        }
        void ShowInventory()
        {
            ShowRoyalInventory();
        }
        void ShowLegacyInventory()
        {
            PanelHeader("가방 · 장비");var items=ReviewState.Inventory().Where(i=>i.Count>0).ToList();
            var row=Row(modal);row.style.marginTop=10;row.style.alignItems=Align.Center;Text(row,items.Count+"개 보관",14).style.flexGrow=1;
            GrowthButton(row,"추천 장착",ReviewState.RecommendEquip,ShowInventory,items.Count>0);GrowthNotice(modal);
            if(PersistentPlayer)
            {
                var mail=Button(modal,"보관함 · "+ReviewState.UnityEquipmentMail().Count+"개",ShowUnityEquipmentMail);mail.style.marginLeft=0;mail.style.marginTop=8;
                if(ReviewState.HasDeferredUnityLoot)Text(modal,"가방·보관함이 가득 차 사냥이 대기 중입니다. 장비를 정리하고 보관함에서 수령하세요.",12).style.whiteSpace=WhiteSpace.Normal;
                if(ReviewState.Snapshot()["unity_last_loot"] is JObject receipt&&receipt["items"] is JArray last)Text(modal,"최근 무리 · 장비 "+last.Count+"개 획득 · 가방 "+items.Count+" / "+GameStateCommands.UnityBagCapacity,12).style.color=Moss;
            }
            VisualElement Make()
            {
                var card=new Button();card.AddToClassList("inventory-card");card.clicked+=()=>{if(card.userData is string id)ShowInventoryItem(id);};
                var name=new Label{name="item-name"};name.AddToClassList("hero-roster-name");card.Add(name);var detail=new Label{name="item-detail"};detail.AddToClassList("hero-roster-detail");card.Add(detail);return card;
            }
            void Bind(VisualElement card,int index)
            {
                var item=items[index];card.userData=(string)item["id"];card.Q<Label>("item-name").text=((bool)item["locked"]?"잠금 · ":"")+item["name"]+" +"+item["level"];
                card.Q<Label>("item-detail").text=SlotName((string)item["slot"])+" · "+item["rarity"]+" · "+item["set"]+" · 전투력 "+item["power"];
                card.Q<Label>("item-name").style.color=(string)item["rarity"]=="전설"?Bronze:Parchment;
            }
            var list=new ListView(items,65,Make,Bind){selectionType=SelectionType.None};list.style.flexGrow=1;list.style.marginTop=8;list.unbindItem=(element,_)=>element.userData=null;modal.Add(list);
            if(items.Count==0)Text(modal,"보관 중인 장비가 없습니다.",14);
        }
        void ShowInventoryItem(string id,bool confirmSalvage=false)
        {
            var item=ReviewState.Inventory().FirstOrDefault(i=>(string)i["id"]==id);if(item==null){ShowInventory();return;}
            PanelHeader((string)item["name"]);var scroll=new ScrollView();scroll.style.flexGrow=1;modal.Add(scroll);
            Text(scroll,SlotName((string)item["slot"])+" · "+item["rarity"]+" · +"+item["level"],18).style.marginTop=14;
            Text(scroll,"세트 "+item["set"]+" · 전투력 "+item["power"],14).style.color=Moss;
            Text(scroll,(string)item["origin"]=="raid"?"레이드 장비":(string)item["origin"]=="hunt"?"사냥터 장비":"기존 장비",13);
            foreach(JObject affix in item["affixes"])
            {string stat=(string)affix["stat"];Text(scroll,(stat=="attack_pct"?"공격력":stat=="hp_pct"?"체력":stat=="defense"?"방어력":stat=="haste_pct"?"공격 속도":"궁극기 충전")+" +"+affix["value"]+(stat=="defense"?"":"%"),14);}
            GrowthNotice(scroll);bool equipment=(string)item["item_type"]=="equipment";bool pending=((JObject)item["proposal"]).Count>0;int level=(int)item["level"];
            var choose=Button(scroll,"장착할 영웅 선택",()=>ShowEquipmentTargets(id));choose.style.marginTop=14;choose.style.marginLeft=0;choose.SetEnabled(equipment&&!pending);
            int cost=LegacyGrowthEconomy.EquipmentCost((string)item["slot"],level);
            GrowthButton(scroll,level>=10?"최대 강화":"강화 · "+cost.ToString("N0")+" 골드",()=>ReviewState.EnhanceGear(id),()=>ShowInventoryItem(id),equipment&&level<10&&ReviewState.WalletGold>=cost).style.marginTop=8;
            GrowthButton(scroll,(bool)item["locked"]?"잠금 해제":"장비 잠금",()=>ReviewState.ToggleGearLock(id),()=>ShowInventoryItem(id)).style.marginTop=8;
            bool canSalvage=equipment&&!(bool)item["locked"]&&!pending;
            if(equipment)Button(scroll,"공방 · 옵션 조율 / 추출 / 이식",()=>ShowWorkshop(id)).style.marginTop=8;
            var salvage=Button(scroll,"분해 · 골드 "+OriginalEquipmentRules.SalvageValue(item),()=>
            {
                if(OriginalEquipmentRules.Protected(item)&&!confirmSalvage){ShowInventoryItem(id,true);return;}
                StateCommand(()=>ReviewState.DecomposeGear(id,true),ShowInventory);
            });salvage.style.marginLeft=0;salvage.style.marginTop=18;salvage.SetEnabled(GrowthAllowed&&canSalvage);
            if(confirmSalvage){salvage.text="이 장비 분해하기";Text(scroll,"레이드·옵션 장비가 사라지고 골드를 받습니다.",13).style.whiteSpace=WhiteSpace.Normal;}
            Button(scroll,"가방으로",ShowInventory).style.marginLeft=0;
        }
        void ShowEquipmentTargets(string id)
        {
            var item=ReviewState.Inventory().FirstOrDefault(i=>(string)i["id"]==id);if(item==null){ShowInventory();return;}
            PanelHeader("장착할 영웅");var list=new ScrollView();list.style.flexGrow=1;modal.Add(list);
            foreach(string hero in ReviewState.DeployedHeroes())
            {
                string selected=hero;var h=Simulation.Catalog.Hero(hero);string position=ReviewState.EquipmentPositionFor(item,hero);var old=ReviewState.EquippedItem(hero,position);
                var b=GrowthButton(list,(string)h["name"]+" · "+((int?)old["power"]??0)+" → "+item["power"],()=>ReviewState.EquipGear(id,selected,position),()=>ShowGrowth(selected),position.Length>0);b.style.marginTop=8;
            }
            Button(list,"장비로",()=>ShowInventoryItem(id)).style.marginLeft=0;
        }
        void ShowStateMenu() => BuildLegacyMenu();
        void ShowUnityEquipmentMail()
        {
            PanelHeader("장비 보관함");var items=ReviewState.UnityEquipmentMail();
            Text(modal,"가방 "+ReviewState.Inventory().Count+" / 200 · 보관함 "+items.Count+" / 3000",14).style.marginTop=10;
            Text(modal,"가방 초과 장비는 보관함으로 배송됩니다. 수령하면 가방에서 장착할 수 있습니다.",12).style.whiteSpace=WhiteSpace.Normal;
            GrowthButton(modal,"빈칸만큼 수령",ReviewState.ClaimUnityEquipmentMail,ShowUnityEquipmentMail,items.Count>0||ReviewState.HasDeferredUnityLoot).style.marginTop=8;GrowthNotice(modal);
            var list=new ScrollView();list.style.flexGrow=1;modal.Add(list);
            // A bounded preview keeps thousands of retained attachments usable.
            foreach(var item in items.Take(30))Text(list,item["name"]+" · "+item["rarity"]+" · "+item["set"],12).style.marginTop=8;
            if(items.Count>30)Text(list,"외 "+(items.Count-30)+"개 · 수령 후 가방에서 확인할 수 있습니다.",12).style.marginTop=10;
            Button(modal,"가방으로",ShowInventory).style.marginTop=8;
        }
    }
}
