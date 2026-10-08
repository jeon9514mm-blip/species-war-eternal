using System;
using System.Linq;
using Newtonsoft.Json.Linq;
using UnityEngine;
using UnityEngine.UIElements;

namespace Eternal.UnityMigration
{
    public sealed partial class HuntingMigrationReview
    {
        string growthMessage="";
        bool GrowthAllowed=>Raid==null&&ReviewState.MutationError.Length==0;
        static string SlotName(string slot)=>slot=="weapon"?"무기":slot=="armor"?"갑옷":"장신구";
        void StateCommand(Func<StateCommandResult> command,Action refresh)
        {
            if(!GrowthAllowed){growthMessage=Raid!=null?"레이드를 마친 뒤 성장을 변경하세요.":ReviewState.MutationError;refresh();return;}
            var result=command();growthMessage=result.Message+(result.SavePending?" · 저장 대기":"");
            if(result.Ok)Simulation.RefreshHeroGrowth();refresh();RefreshHud();
        }
        void GrowthNotice(VisualElement parent)
        {
            if(growthMessage.Length==0)return;var notice=Text(parent,growthMessage,13);notice.style.whiteSpace=WhiteSpace.Normal;notice.style.color=Moss;notice.style.marginTop=12;notice.style.marginBottom=8;
        }
        Button GrowthButton(VisualElement parent,string title,Func<StateCommandResult> command,Action refresh,bool allowed=true)
        {var b=Button(parent,title,()=>StateCommand(command,refresh));b.style.marginLeft=0;b.style.marginRight=6;b.SetEnabled(GrowthAllowed&&allowed);return b;}
        void ShowGrowth(string id)
        {
            if(!ReviewState.IsFactionHero(id)){ShowHero(id);return;}
            var hero=Simulation.Catalog.Hero(id);PanelHeader((string)hero["name"]+" · 성장");
            var scroll=new ScrollView();scroll.style.flexGrow=1;modal.Add(scroll);
            var top=Row(scroll);top.style.marginTop=12;top.style.alignItems=Align.Center;
            var art=new Image{sprite=InspectionPortrait(id),scaleMode=ScaleMode.ScaleToFit};art.style.width=74;art.style.height=94;art.style.marginRight=10;top.Add(art);
            var info=new VisualElement();top.Add(info);var progress=ReviewState.HeroProgress(id);var profile=ReviewState.CombatProfile(id);
            Text(info,"Lv."+progress.level+" · "+ReviewState.Grade(id)+" · "+(string)hero["role_group"],17).style.color=Bronze;
            Text(info,"공격 "+profile["attack"]+"  방어 "+profile["defense"],14);
            Text(info,"최대 체력 "+profile["max_hp"],14);Text(info,"경험치 "+progress.xp+" / "+(progress.level>=100?"MAX":LegacyGrowthEconomy.XpCost(progress.level,100).ToString()),12).style.color=Moss;
            Button(scroll,"스킬 보기",()=>ShowHero(id)).style.marginLeft=0;
            GrowthNotice(scroll);
            var tree=ReviewState.HeroTree(id);Text(scroll,"연구 · 남은 포인트 "+tree.available,17).style.marginTop=12;
            foreach(string branch in new[]{"offense","survival","utility"})
            {
                string selected=branch;int rank=branch=="offense"?tree.offense:branch=="survival"?tree.survival:tree.utility;
                string name=branch=="offense"?"공격":branch=="survival"?"생존":"유틸리티";
                var row=Row(scroll);row.style.alignItems=Align.Center;row.style.marginTop=7;
                var label=Text(row,name+"  "+rank+" / 10",14);label.style.flexGrow=1;
                GrowthButton(row,"연구 +1",()=>ReviewState.UpgradeResearch(id,selected),()=>ShowGrowth(id),tree.available>0&&rank<10);
            }
            Text(scroll,"장착 장비",17).style.marginTop=16;
            Text(scroll,(string)ReviewState.EquipmentProfile(id)["summary"],12).style.whiteSpace=WhiteSpace.Normal;
            foreach(string slot in OriginalEquipmentRules.Slots)
            {
                string selected=slot;var item=ReviewState.EquippedItem(id,slot);int level=(int)item["level"];int cost=LegacyGrowthEconomy.EquipmentCost(slot,level);
                var block=new VisualElement();block.AddToClassList("growth-gear-card");scroll.Add(block);
                Text(block,SlotName(slot)+" · "+item["name"]+" +"+level,14).style.whiteSpace=WhiteSpace.Normal;
                Text(block,item["rarity"]+" · "+item["set"]+" · 전투력 "+item["power"],12).style.color=Moss;
                GrowthButton(block,level>=10?"최대 강화":"강화 · "+cost.ToString("N0")+" 골드",()=>ReviewState.EnhanceGear((string)item["id"],id,selected),()=>ShowGrowth(id),level<10&&ReviewState.WalletGold>=cost).style.marginTop=6;
            }
            var ranks=ReviewState.Snapshot();int asc=(int)GameStateCommands.Integer((ranks["hero_ascension"] as JObject)?[id],0,0,3),rankBreak=(int)GameStateCommands.Integer((ranks["hero_breakthrough"] as JObject)?[id],0,0,5),shards=(int)GameStateCommands.Integer((ranks["hero_shards"] as JObject)?[id],0,0,100000000);
            int ascCost=1200+asc*1800,requiredLevel=10+asc*10,breakCost=20+rankBreak*20;
            Text(scroll,"승급 · 돌파",17).style.marginTop=16;
            Text(scroll,"조각 "+shards+" · 돌파 "+rankBreak+" / 5",13).style.color=Moss;
            GrowthButton(scroll,ReviewState.Grade(id)=="UR"?"최고 등급 UR":"승급 · Lv."+requiredLevel+" / "+ascCost.ToString("N0")+" 골드",()=>ReviewState.Ascend(id),()=>ShowGrowth(id),ReviewState.Grade(id)!="UR"&&progress.level>=requiredLevel&&ReviewState.WalletGold>=ascCost).style.marginTop=6;
            GrowthButton(scroll,rankBreak>=5?"최대 돌파":"돌파 · 조각 "+breakCost,()=>ReviewState.Breakthrough(id),()=>ShowGrowth(id),rankBreak<5&&shards>=breakCost).style.marginTop=6;
        }
        void ShowInventory()
        {
            PanelHeader("가방 · 장비");var items=ReviewState.Inventory().Where(i=>i.Count>0).ToList();
            var row=Row(modal);row.style.marginTop=10;row.style.alignItems=Align.Center;Text(row,items.Count+"개 보관",14).style.flexGrow=1;
            GrowthButton(row,"추천 장착",ReviewState.RecommendEquip,ShowInventory,items.Count>0);GrowthNotice(modal);
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
                string selected=hero;var h=Simulation.Catalog.Hero(hero);var old=ReviewState.EquippedItem(hero,(string)item["slot"]);
                var b=GrowthButton(list,(string)h["name"]+" · "+old["power"]+" → "+item["power"],()=>ReviewState.EquipGear(id,selected),()=>ShowGrowth(selected));b.style.marginTop=8;
            }
            Button(list,"장비로",()=>ShowInventoryItem(id)).style.marginLeft=0;
        }
        void ShowStateMenu()
        {
            PanelHeader("원정대 메뉴");var scroll=new ScrollView();scroll.style.flexGrow=1;modal.Add(scroll);Text(scroll,"골드 "+ReviewState.WalletGold.ToString("N0")+" · 젬 "+ReviewState.WalletGems.ToString("N0"),17).style.marginTop=14;GrowthNotice(scroll);
            Text(scroll,(string)ReviewState.PartySynergy()["summary"],13).style.whiteSpace=WhiteSpace.Normal;Text(scroll,"수호신 · "+(string)HuntingSimulation.Canonical["catalogs"]["guardian"]["data"]["DEFINITIONS"][ReviewState.EquippedGuardian]["name"],15).style.marginTop=12;
            GrowthButton(scroll,"일일 보상 · 젬 30 / 골드 100",()=>ReviewState.ClaimDaily(DateTime.Now.ToString("yyyy-MM-dd")),ShowStateMenu).style.marginTop=16;
            var snapshot=ReviewState.Snapshot();long claim=GameStateCommands.Integer(snapshot["unclaimed_gold"],0,0,GameStateCommands.CurrencyCap)+GameStateCommands.Integer(snapshot["idle_chest_gold"],0,0,GameStateCommands.CurrencyCap);
            long claimXp=GameStateCommands.Integer(snapshot["unclaimed_xp"],0,0,GameStateCommands.CurrencyCap)+GameStateCommands.Integer(snapshot["idle_chest_xp"],0,0,GameStateCommands.CurrencyCap);
            GrowthButton(scroll,"보관 보상 수령 · 골드 "+claim.ToString("N0"),ReviewState.ClaimHuntingRewards,ShowStateMenu,claim>0||claimXp>0).style.marginTop=8;
            Text(scroll,"사냥 연출 검수 · 골드 "+Simulation.Gold.ToString("N0")+" / 경험치 "+Simulation.Xp.ToString("N0"),13).style.marginTop=20;
            Text(scroll,"독립 검수 기록입니다. 성장·장비 변경은 이번 실행에 유지되며 기존 저장 기록에는 반영되지 않습니다.",13).style.whiteSpace=WhiteSpace.Normal;Text(scroll,"사냥 보상·소환·수호신 전투·콘텐츠 저장 이관은 계속 진행 중입니다.",12).style.whiteSpace=WhiteSpace.Normal;
        }
    }
}
