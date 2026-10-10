using System;
using System.Collections.Generic;
using System.Linq;
using Newtonsoft.Json.Linq;
using UnityEngine;
using UnityEngine.UIElements;

namespace Eternal.UnityMigration
{
    public sealed partial class HuntingMigrationReview
    {
        string inventoryCategory="weapon",inventoryItem="",inventoryHero="",inventoryPosition="",inventorySort="전투력순";
        Vector2 inventoryOffset;
        static readonly string[] BagCategories={"weapon","armor","accessory","material"},BagCategoryLabels={"무기","장비","악세서리","재료"};
        static readonly Color GearGold=new(.80f,.66f,.43f),GearSilver=new(.65f,.73f,.78f),GearBlue=new(.34f,.64f,.89f);
        static Color GearColor(JObject item)=>(string)item?["rarity"]=="전설"?GearGold:(string)item?["rarity"]=="희귀"?GearBlue:GearSilver;
        static VisualElement ArmoryPanel(VisualElement parent,string name)
        {
            var box=new VisualElement{name=name};box.style.position=Position.Relative;box.style.paddingLeft=box.style.paddingRight=12;box.style.paddingTop=box.style.paddingBottom=12;box.style.minWidth=0;box.style.minHeight=0;
            box.Add(new RoyalHudSurface(ornate:true,accent:GearGold));parent.Add(box);return box;
        }
        static void ArmoryButton(Button button,bool active=false)
        {
            button.style.height=42;button.style.minHeight=42;button.style.marginLeft=0;button.style.marginRight=6;button.style.flexShrink=0;
            button.style.backgroundColor=active?new Color(.32f,.25f,.15f):new Color(.055f,.073f,.087f);button.style.color=active?new Color(1,.90f,.68f):new Color(.84f,.87f,.85f);
            button.style.borderLeftWidth=button.style.borderRightWidth=button.style.borderTopWidth=button.style.borderBottomWidth=1;
            button.style.borderLeftColor=button.style.borderRightColor=button.style.borderTopColor=button.style.borderBottomColor=active?GearGold:new Color(.27f,.31f,.33f);
            button.style.borderTopLeftRadius=button.style.borderTopRightRadius=button.style.borderBottomLeftRadius=button.style.borderBottomRightRadius=4;
        }
        void ArmoryChrome()
        {
            modal.style.backgroundColor=new Color(.025f,.034f,.044f,.98f);modal.Insert(0,new RoyalHudSurface(ornate:true,accent:GearGold));
            modal.Q<Label>("inspection-title").style.color=GearGold;ArmoryButton(modal.Q<Button>("inspection-close"));
        }
        string BagHero()
        {
            if(!ReviewState.IsFactionHero(inventoryHero))inventoryHero=ReviewState.IsFactionHero(heroShowcaseId)?heroShowcaseId:ReviewState.DeployedHeroes().FirstOrDefault()??"";
            return inventoryHero;
        }
        void OpenEquipmentSlot(string hero,string position)
        {inventoryHero=hero;inventoryPosition=position;inventoryCategory=NativeEquipmentLayout.Category(position);inventoryItem="";inventoryOffset=Vector2.zero;ShowInventory();}
        void ShowRoyalInventory()
        {
            if(modal.Q<ScrollView>("RoyalBagGridScroll") is ScrollView old)inventoryOffset=old.scrollOffset;
            PanelHeader("가방 · 원정대 보급");ConfigureInspection(InspectionLayout.Wide);ArmoryChrome();
            var screen=new VisualElement{name="RoyalInventoryScreen"};screen.style.flexGrow=1;screen.style.minHeight=0;modal.Add(screen);
            var items=ReviewState.Inventory().Where(i=>i.Count>0).ToList();var toolbar=Row(screen);toolbar.style.alignItems=Align.Center;toolbar.style.marginBottom=10;
            ShowcaseText(toolbar,items.Count+" / "+GameStateCommands.UnityBagCapacity+"   보관",14,GearGold).style.flexGrow=1;
            var sort=new DropdownField(new List<string>{"전투력순","희귀도순","강화순"},inventorySort){name="BagSort"};sort.style.width=150;sort.style.marginRight=10;
            sort.RegisterValueChangedCallback(e=>{inventorySort=e.newValue;ShowInventory();});toolbar.Add(sort);
            var auto=GrowthButton(toolbar,"자동장착",ReviewState.RecommendEquip,ShowInventory,items.Any(i=>(string)i["item_type"]=="equipment"));auto.name="BagAutoEquip";auto.tooltip="출전 영웅에게 더 강한 장비를 배분합니다. 잠금과 세트 효과를 보호합니다.";ArmoryButton(auto,true);
            if(PersistentPlayer){var mail=Button(toolbar,"보관함 "+ReviewState.UnityEquipmentMail().Count,ShowUnityEquipmentMail);mail.name="BagEquipmentMail";ArmoryButton(mail);}
            var body=Row(screen);body.style.flexGrow=1;body.style.minHeight=0;
            var storage=ArmoryPanel(body,"RoyalBagStorage");storage.style.flexGrow=1;storage.style.flexBasis=0;storage.style.marginRight=14;
            var tabs=Row(storage);tabs.style.flexShrink=0;tabs.style.marginBottom=12;
            for(int n=0;n<BagCategories.Length;n++)
            {
                string category=BagCategories[n];int count=items.Count(i=>(string)i["item_type"]=="equipment"?NativeEquipmentLayout.Category((string)i["slot"])==category:category=="material");
                if(category=="material")count+=MaterialStacks().Count;
                var tab=Button(tabs,BagCategoryLabels[n]+"  "+count,()=>{inventoryCategory=category;inventoryPosition="";inventoryItem="";inventoryOffset=Vector2.zero;ShowInventory();});
                tab.name="BagCategory_"+category;tab.style.flexGrow=1;tab.style.flexBasis=0;ArmoryButton(tab,category==inventoryCategory);
            }
            if(inventoryPosition.Length>0){var filter=Button(storage,NativeEquipmentLayout.Label(inventoryPosition)+" 장착 후보 · 전체 보기",()=>{inventoryPosition="";ShowInventory();});ArmoryButton(filter);filter.name="BagSlotFilter";}
            var scroll=new ScrollView(ScrollViewMode.Vertical){name="RoyalBagGridScroll"};scroll.style.flexGrow=1;scroll.style.minHeight=0;scroll.horizontalScrollerVisibility=ScrollerVisibility.Hidden;storage.Add(scroll);
            var grid=new VisualElement{name="RoyalBagGrid"};grid.style.flexDirection=FlexDirection.Row;grid.style.flexWrap=Wrap.Wrap;grid.style.alignContent=Align.FlexStart;scroll.Add(grid);
            var filtered=items.Where(i=>(string)i["item_type"]=="equipment"?NativeEquipmentLayout.Category((string)i["slot"])==inventoryCategory:inventoryCategory=="material")
                .Where(i=>inventoryPosition.Length==0||NativeEquipmentLayout.Fits((string)i["slot"],inventoryPosition));
            filtered=inventorySort=="희귀도순"?filtered.OrderByDescending(i=>OriginalEquipmentRules.RarityRank((string)i["rarity"])).ThenByDescending(i=>(int)i["power"]):inventorySort=="강화순"?filtered.OrderByDescending(i=>(int)i["level"]).ThenByDescending(i=>(int)i["power"]):filtered.OrderByDescending(i=>(int)i["power"]).ThenBy(i=>(string)i["id"]);
            var visible=filtered.ToList();if(!visible.Any(i=>(string)i["id"]==inventoryItem))inventoryItem=(string)visible.FirstOrDefault()?["id"]??"";
            foreach(var item in visible)
            {
                string key=(string)item["id"];var card=EquipmentCard(grid,item,key==inventoryItem,()=>{inventoryItem=key;ShowInventory();});card.name="BagItem_"+key;
            }
            if(inventoryCategory=="material")foreach(var stack in MaterialStacks())
            {
                var card=EquipmentCard(grid,new JObject{{"name",stack.name},{"slot","material"},{"rarity","희귀"},{"level",0},{"power",0}},false,()=>ShowMaterialInfo(stack.name,stack.amount));card.name="BagMaterial_"+stack.name;
                ShowcaseText(card,stack.amount.ToString("N0"),12,GearGold).style.unityTextAlign=TextAnchor.MiddleRight;
            }
            if(visible.Count==0&&(inventoryCategory!="material"||MaterialStacks().Count==0))ShowcaseText(grid,"보관 중인 "+BagCategoryLabels[Array.IndexOf(BagCategories,inventoryCategory)]+"이 없습니다.",15,Moss).style.marginTop=32;
            scroll.schedule.Execute(()=>scroll.scrollOffset=inventoryOffset);
            var details=ArmoryPanel(body,"RoyalBagDetails");details.style.width=328;details.style.flexShrink=0;BuildBagDetails(details,visible.FirstOrDefault(i=>(string)i["id"]==inventoryItem));
            GrowthNotice(screen);
            body.RegisterCallback<GeometryChangedEvent>(e=>{bool narrow=e.newRect.width<980;details.style.width=narrow?260:328;storage.style.marginRight=narrow?8:14;});
        }
        Button EquipmentCard(VisualElement parent,JObject item,bool selected,Action action)
        {
            var card=new Button(action);card.text="";card.style.width=104;card.style.height=124;card.style.marginLeft=0;card.style.marginRight=8;card.style.marginBottom=8;card.style.paddingLeft=card.style.paddingRight=7;card.style.paddingTop=7;card.style.paddingBottom=5;
            card.style.backgroundColor=selected?new Color(.21f,.18f,.12f):new Color(.055f,.073f,.087f);card.style.borderLeftWidth=card.style.borderRightWidth=card.style.borderTopWidth=card.style.borderBottomWidth=selected?2:1;
            card.style.borderLeftColor=card.style.borderRightColor=card.style.borderTopColor=card.style.borderBottomColor=selected?GearGold:GearColor(item)*new Color(1,1,1,.55f);
            card.style.borderTopLeftRadius=card.style.borderTopRightRadius=card.style.borderBottomLeftRadius=card.style.borderBottomRightRadius=5;
            var icon=new RoyalEquipmentIcon((string)item["slot"],GearColor(item));icon.style.width=58;icon.style.height=58;icon.style.alignSelf=Align.Center;card.Add(icon);
            var title=ShowcaseText(card,(string)item["name"],11,Parchment);title.style.whiteSpace=WhiteSpace.NoWrap;title.style.overflow=Overflow.Hidden;title.style.textOverflow=TextOverflow.Ellipsis;
            ShowcaseText(card,(string)item["slot"]=="material"?"보유 재료":(string)item["item_type"]=="option_crystal"?"옵션 결정":NativeEquipmentLayout.Label((string)item["slot"])+"  +"+item["level"],11,GearColor(item));
            if((string)item["item_type"]=="equipment")ShowcaseText(card,((bool?)item["locked"]==true?"잠금 · ":"")+"전투력 "+item["power"],10,Moss);
            card.tooltip=(string)item["name"]+" · "+(string)item["rarity"];parent.Add(card);return card;
        }
        void BuildBagDetails(VisualElement parent,JObject item)
        {
            var scroll=new ScrollView(ScrollViewMode.Vertical);scroll.style.flexGrow=1;scroll.style.minHeight=0;scroll.horizontalScrollerVisibility=ScrollerVisibility.Hidden;parent.Add(scroll);
            if(item==null){ShowcaseText(scroll,"아이템을 선택하세요",20,GearGold);ShowcaseText(scroll,"종류별로 장비를 살펴보고 영웅에게 장착할 수 있습니다.",13,Moss);return;}
            var icon=new RoyalEquipmentIcon((string)item["slot"],GearColor(item));icon.style.width=100;icon.style.height=100;icon.style.alignSelf=Align.Center;scroll.Add(icon);
            ShowcaseText(scroll,(string)item["name"],21,GearColor(item));ShowcaseText(scroll,item["rarity"]+" · "+NativeEquipmentLayout.Label((string)item["slot"])+" · +"+item["level"],13,Moss);
            ShowcaseText(scroll,"전투력   "+item["power"],22,Parchment).style.marginTop=12;ShowcaseText(scroll,"세트 · "+item["set"],13,GearGold);
            foreach(JObject affix in item["affixes"])ShowcaseText(scroll,AffixLabel((string)affix["stat"])+" +"+affix["value"]+((string)affix["stat"]=="defense"?"":"%"),13,Moss);
            string key=(string)item["id"];bool equipment=(string)item["item_type"]=="equipment",pending=((JObject)item["proposal"]).Count>0;int level=(int)item["level"];
            if(equipment)
            {
                var ids=Simulation.Catalog.HeroIds.Where(ReviewState.IsFactionHero).ToList();var names=ids.Select(id=>(string)Simulation.Catalog.Hero(id)["name"]).ToList();string hero=BagHero();int index=ids.IndexOf(hero);
                ShowcaseText(scroll,"장착할 영웅",12,Moss).style.marginTop=12;var choose=new DropdownField(names,Math.Max(0,index)){name="BagTargetHero"};
                choose.RegisterValueChangedCallback(e=>{int at=names.IndexOf(e.newValue);if(at>=0){inventoryHero=ids[at];ShowInventory();}});scroll.Add(choose);
                var positions=NativeEquipmentLayout.Matching((string)item["slot"]);string position=positions.Contains(inventoryPosition)?inventoryPosition:ReviewState.EquipmentPositionFor(item,hero);
                if(positions.Length>1)
                {var ring=new DropdownField(positions.Select(NativeEquipmentLayout.Label).ToList(),Math.Max(0,Array.IndexOf(positions,position))){name="BagRingPosition"};ring.RegisterValueChangedCallback(e=>{inventoryPosition=positions[ring.index];ShowInventory();});scroll.Add(ring);}
                var current=ReviewState.EquippedItem(hero,position);ShowcaseText(scroll,(current.Count==0?"미장착":(string)current["name"])+"  "+((int?)current["power"]??0)+" → "+item["power"],12,GearGold).style.marginTop=8;
                var comparison=ReviewState.CompareEquipment(key,hero,position);
                if(comparison.Count>0)foreach(var stat in new[]{("attack","공격력"),("defense","방어력"),("hp","체력")})
                {int was=(int)comparison["before"][stat.Item1],after=(int)comparison["after"][stat.Item1];ShowcaseText(scroll,stat.Item2+"  "+was.ToString("N0")+" → "+after.ToString("N0")+"  ("+(after>=was?"+":"")+(after-was).ToString("N0")+")",12,after>was?new Color(.50f,.79f,.57f):after<was?new Color(.91f,.46f,.39f):Moss);}
                var equip=GrowthButton(scroll,"장착",()=>ReviewState.EquipGear(key,hero,position),ShowInventory,!pending&&position.Length>0);equip.name="BagEquipItem";ArmoryButton(equip,true);
                int cost=LegacyGrowthEconomy.EquipmentCost((string)item["slot"],level);
                var enhance=GrowthButton(scroll,level>=10?"최대 강화":"강화 · "+cost.ToString("N0")+" 골드",()=>ReviewState.EnhanceGear(key),ShowInventory,level<10&&ReviewState.WalletGold>=cost);enhance.name="BagEnhanceItem";ArmoryButton(enhance);
            }
            var lockButton=GrowthButton(scroll,(bool)item["locked"]?"잠금 해제":"잠금",()=>ReviewState.ToggleGearLock(key),ShowInventory);lockButton.name="BagLockItem";ArmoryButton(lockButton);
            var more=Button(scroll,equipment?"공방 · 분해 · 상세":"옵션 결정 상세",()=>ShowInventoryItem(key));more.name="BagAdvancedItem";ArmoryButton(more);
        }
        static string AffixLabel(string stat)=>stat=="attack_pct"?"공격력":stat=="hp_pct"?"체력":stat=="defense"?"방어력":stat=="haste_pct"?"공격 속도":"각성 충전";
        List<(string name,long amount)> MaterialStacks()
        {
            var list=new List<(string,long)>();if(ReviewState.RaidCrystals>0)list.Add(("레이드 정수",ReviewState.RaidCrystals));
            if(ReviewState.Snapshot()["hero_shards"] is JObject shards)foreach(var p in shards.Properties()){long n=GameStateCommands.Integer(p.Value,0,0,GameStateCommands.CurrencyCap);if(n>0&&Simulation.Catalog.HeroIds.Contains(p.Name))list.Add(((string)Simulation.Catalog.Hero(p.Name)["name"]+" 조각",n));}return list;
        }
        void ShowMaterialInfo(string name,long amount)
        {
            var details=modal.Q("RoyalBagDetails");if(details==null)return;details.Clear();details.Add(new RoyalHudSurface(ornate:true,accent:GearGold));
            ShowcaseText(details,name,22,GearGold);ShowcaseText(details,"보유 수량 "+amount.ToString("N0"),17,Parchment);ShowcaseText(details,name=="레이드 정수"?"장비 공방의 옵션 조율·추출에 사용하는 재료입니다.":"영웅 돌파에 사용하는 조각입니다.",14,Moss);
            var go=Button(details,name=="레이드 정수"?"장비 선택":"영웅으로",()=>{if(name=="레이드 정수"){inventoryCategory="weapon";ShowInventory();}else ShowHeroShowcase(BagHero(),"ascension");});ArmoryButton(go,true);
        }
        void AddPortraitEquipment(VisualElement artPanel,Image painting,string id,List<Action> bindings)
        {
            painting.RemoveFromHierarchy();var stage=Row(artPanel);stage.name="HeroEquipmentStage";stage.style.flexGrow=1;stage.style.minHeight=0;stage.style.alignItems=Align.Stretch;
            var left=new VisualElement{name="HeroEquipmentLeft"};left.style.width=86;left.style.flexShrink=0;left.style.justifyContent=Justify.SpaceAround;stage.Add(left);
            painting.style.width=StyleKeyword.Auto;painting.style.flexGrow=1;painting.style.flexBasis=0;painting.style.minWidth=0;stage.Add(painting);
            var right=new VisualElement{name="HeroEquipmentRight"};right.style.width=86;right.style.flexShrink=0;right.style.justifyContent=Justify.SpaceAround;stage.Add(right);
            for(int n=0;n<NativeEquipmentLayout.Positions.Length;n++)
            {
                string position=NativeEquipmentLayout.Positions[n];var column=n<5?left:right;var button=new Button(()=>OpenEquipmentSlot(id,position)){name="HeroGearSlot_"+position};button.text="";
                button.style.marginLeft=button.style.marginRight=0;button.style.marginTop=button.style.marginBottom=3;button.style.paddingLeft=button.style.paddingRight=3;button.style.paddingTop=button.style.paddingBottom=2;button.style.minHeight=54;button.style.maxHeight=82;button.style.flexGrow=1;
                button.style.backgroundColor=new Color(.035f,.05f,.064f,.95f);button.style.borderLeftWidth=button.style.borderRightWidth=button.style.borderTopWidth=button.style.borderBottomWidth=1;
                var glyph=new RoyalEquipmentIcon(position,GearGold);glyph.style.height=37;glyph.style.width=42;glyph.style.alignSelf=Align.Center;button.Add(glyph);
                var label=ShowcaseText(button,NativeEquipmentLayout.Label(position),11,Parchment);label.style.unityTextAlign=TextAnchor.MiddleCenter;
                var state=ShowcaseText(button,"",10,Moss);state.style.position=Position.Absolute;state.style.top=2;state.style.right=4;column.Add(button);
                bindings.Add(()=>{var item=ReviewState.EquippedItem(id,position);bool filled=item.Count>0;glyph.style.opacity=filled?1:.25f;state.text=filled?"+"+item["level"]:"";button.tooltip=filled?item["name"]+" · "+item["rarity"]:"미장착 · "+NativeEquipmentLayout.Label(position)+" 선택";var color=filled?GearColor(item):new Color(.25f,.29f,.31f);state.style.color=color;button.style.borderLeftColor=button.style.borderRightColor=button.style.borderTopColor=button.style.borderBottomColor=color;button.SetEnabled(ReviewState.IsFactionHero(id));});
            }
            var auto=GrowthButton(artPanel,"자동장착",()=>ReviewState.RecommendHeroEquip(id),()=>ShowHeroShowcase(id),ReviewState.IsFactionHero(id));auto.name="HeroAutoEquip";ArmoryButton(auto,true);auto.style.marginTop=8;
        }
    }
}
