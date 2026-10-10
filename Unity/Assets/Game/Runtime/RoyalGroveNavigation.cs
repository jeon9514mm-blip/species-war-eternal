using System;
using System.Collections.Generic;
using Newtonsoft.Json.Linq;
using UnityEngine;
using UnityEngine.UIElements;

namespace Eternal.UnityMigration
{
    public sealed partial class RoyalGroveHuntHud
    {
        readonly Dictionary<string,Button> navigation=new();
        readonly Dictionary<string,VisualElement> navigationLines=new();
        VisualElement navigationItems,navigationSheet;
        ScrollView navigationContent;
        Label navigationTitle;
        string navigationRoute="사냥";
        bool pausedBeforeSheet;

        void BuildNavigation()
        {
            var dock=new VisualElement{name="grove-bottom-navigation",pickingMode=PickingMode.Ignore};
            dock.style.position=Position.Absolute;dock.style.left=dock.style.right=dock.style.bottom=0;
            dock.style.height=76;dock.Add(new RoyalHudSurface(false,true));safe.Add(dock);
            navigationItems=Row(dock,"grove-navigation-items");navigationItems.style.height=76;
            navigationItems.style.alignSelf=Align.Center;navigationItems.style.alignItems=Align.Center;
            string[] routes={"사냥","영웅","레이드","던전","가방"};
            string[] icons={"sword","hero","raid","dungeon","bag"};
            for(int i=0;i<routes.Length;i++)
            {
                string route=routes[i];
                if(i>0)
                {
                    var divider=new VisualElement{pickingMode=PickingMode.Ignore};divider.style.width=1;
                    divider.style.height=18;divider.style.backgroundColor=new Color(Bronze.r,Bronze.g,Bronze.b,.55f);
                    divider.style.flexShrink=0;navigationItems.Add(divider);
                }
                var button=new Button(()=>Navigate(route)){name="grove-navigation-"+route};
                CleanButton(button);button.AddToClassList("royal-nav-button");button.tooltip=route;
                button.style.position=Position.Relative;button.style.flexGrow=1;button.style.flexBasis=0;
                button.style.height=72;button.style.flexDirection=FlexDirection.Row;Border(button,Color.clear,0);
                button.style.backgroundColor=Color.clear;navigationItems.Add(button);
                VisualElement icon=i==0?new Sigil("crest",Bronze):new GodotHudIcon(icons[i],Pale,true);
                icon.style.width=icon.style.height=i==0?37:30;icon.style.marginRight=12;button.Add(icon);
                var title=Text(button,route,19);title.style.unityFontStyleAndWeight=FontStyle.Bold;
                var underline=new VisualElement{pickingMode=PickingMode.Ignore};underline.style.position=Position.Absolute;
                underline.style.left=Length.Percent(16);underline.style.right=Length.Percent(16);underline.style.bottom=5;
                underline.style.height=2;underline.style.backgroundColor=new Color(1,.79f,.40f);
                button.Add(underline);navigation[route]=button;navigationLines[route]=underline;
            }
            navigationSheet=Plate(safe,"grove-navigation-sheet");navigationSheet.pickingMode=PickingMode.Position;
            navigationSheet.style.position=Position.Absolute;navigationSheet.style.left=Length.Percent(22);
            navigationSheet.style.right=205;navigationSheet.style.top=114;navigationSheet.style.bottom=202;
            navigationSheet.style.paddingLeft=navigationSheet.style.paddingRight=23;
            navigationSheet.style.paddingTop=18;navigationSheet.style.paddingBottom=14;
            navigationSheet.style.display=DisplayStyle.None;
            var titleRow=Row(navigationSheet,"grove-navigation-title");titleRow.style.alignItems=Align.Center;
            titleRow.style.height=40;titleRow.style.flexShrink=0;
            navigationTitle=Text(titleRow,"",25);navigationTitle.style.flexGrow=1;navigationTitle.style.color=Bronze;
            var close=ActionButton(titleRow,"닫기",()=>Navigate("사냥"));close.name="grove-navigation-close";close.style.width=72;
            navigationContent=new ScrollView{name="grove-navigation-content"};navigationContent.style.flexGrow=1;
            navigationContent.style.minHeight=0;navigationContent.style.marginTop=16;
            navigationContent.horizontalScrollerVisibility=ScrollerVisibility.Hidden;navigationSheet.Add(navigationContent);
            root.RegisterCallback<KeyDownEvent>(e=>{if(e.keyCode==KeyCode.Escape&&navigationRoute!="사냥"){Navigate("사냥");e.StopPropagation();}});
            RefreshNavigation();
        }
        public void Navigate(string route)
        {
            if(!navigation.ContainsKey(route))throw new ArgumentException("Unknown hunting navigation route.",nameof(route));
            ReleaseStick();
            bool opening=navigationRoute=="사냥"&&route!="사냥";
            if(opening){pausedBeforeSheet=simulation.Paused;simulation.Paused=true;}
            if(route=="사냥"&&navigationRoute!="사냥")simulation.Paused=pausedBeforeSheet;
            navigationRoute=route;navigationSheet.style.display=route=="사냥"?DisplayStyle.None:DisplayStyle.Flex;
            if(route!="사냥")
            {
                navigationTitle.text=route;navigationContent.Clear();
                if(route=="영웅")BuildHeroNavigation();
                else if(route=="레이드")BuildRaidNavigation();
                else if(route=="가방")BuildBagNavigation();
                else BuildDungeonNavigation();
            }
            RefreshNavigation();Refresh(selected);
        }
        void RefreshNavigation()
        {
            foreach(var item in navigation)
            {
                bool active=item.Key==navigationRoute;item.Value.EnableInClassList("selected",active);
                item.Value.style.color=active?new Color(1,.86f,.59f):Muted;
                navigationLines[item.Key].style.display=active?DisplayStyle.Flex:DisplayStyle.None;
                foreach(var icon in item.Value.Query<GodotHudIcon>().ToList())icon.MarkDirtyRepaint();
            }
            SetCombatVisibility();
        }
        void SetCombatVisibility()
        {
            if(navigationSheet==null)return;
            var show=navigationRoute=="사냥"?DisplayStyle.Flex:DisplayStyle.None;
            foreach(var element in new[]{identity,skillRow,zoomRow,stick,stickCaption,rail})element.style.display=show;
        }
        void LayoutNavigation(float width)
        {
            if(navigationItems==null)return;navigationItems.style.width=Mathf.Min(980,width-100);
            navigationSheet.style.left=Length.Percent(width<1260?16:22);
            navigationSheet.style.right=width<1260?24:205;
        }
        VisualElement Card(string title,string detail,string icon,Action click=null)
        {
            VisualElement card;
            if(click!=null){var button=new Button(click);CleanButton(button);card=button;}
            else card=new VisualElement{pickingMode=PickingMode.Ignore};
            card.AddToClassList("royal-sheet-card");card.style.alignItems=Align.Stretch;card.style.flexDirection=FlexDirection.Column;
            card.style.justifyContent=Justify.FlexStart;card.style.paddingLeft=card.style.paddingRight=16;card.style.paddingTop=card.style.paddingBottom=16;
            navigationContent.Add(card);var line=Row(card,"royal-card-title");line.style.alignItems=Align.Center;
            var glyph=new GodotHudIcon(icon,Bronze);glyph.style.width=glyph.style.height=27;glyph.style.marginRight=12;line.Add(glyph);
            var name=Text(line,title,18);name.style.flexGrow=1;name.style.whiteSpace=WhiteSpace.Normal;
            var copy=Text(card,detail,13);copy.style.color=Muted;copy.style.whiteSpace=WhiteSpace.Normal;copy.style.marginTop=8;
            return card;
        }
        void BuildHeroNavigation()
        {
            Text(navigationContent,"원정대 "+simulation.Battle.Heroes.Count+" / 10 · 영웅 정보와 스킬",13).style.color=Muted;
            foreach(var hero in simulation.Battle.Heroes)
            {
                string id=hero.Id;var entry=simulation.Catalog.Hero(id);
                Card(HeroName(id),"Lv."+(simulation.PlayerState?.HeroProgress(id).level??1)+" · "+(string)entry["class"]+
                    " · HP "+Math.Max(0,hero.Hp).ToString("N0")+" / "+hero.MaxHp.ToString("N0"),"hero",()=>BuildHeroDetails(id));
            }
        }
        void BuildHeroDetails(string id)
        {
            navigationContent.Clear();navigationTitle.text=HeroName(id);
            var definition=simulation.Catalog.Hero(id);
            Card((string)definition["class"]??"영웅",(string)definition["race"]??"", "hero");
            if(simulation.Battle.Kits.TryGetValue(id,out var kit))foreach(string slot in Slots)
            {
                if(!kit.Profiles.TryGetValue(slot,out var profile))continue;
                Card((string)profile["skill"]??slot,(string)profile["description"]??
                    "재사용 "+LegacyCombatRules.Number(profile,"cooldown",7).ToString("0.#")+"초",slot=="a2"?"shield":"sword");
            }
            var back=ActionButton(navigationContent,"영웅 목록",()=>Navigate("영웅"));back.style.width=140;
        }
        void BuildRaidNavigation()
        {
            Text(navigationContent,"10인 원정대 · 보스 패턴과 단계",13).style.color=Muted;
            var data=HuntingSimulation.Canonical;
            foreach(string zone in new[]{"gray_meadow","forgotten_mine","moonrest_forest"})
            {
                string id=zone;var boss=data["zones"]?[id];var raid=data["catalogs"]?["raid"]?["data"]?["RAIDS"]?[id];
                if(boss==null||raid==null)continue;
                Card((string)boss["boss"]??id,(string)raid["description"]??"", "raid",()=>
                {
                    navigationContent.Clear();navigationTitle.text=(string)boss["boss"]??"레이드";
                    if(raid["mechanics"] is JArray mechanics)for(int i=0;i<mechanics.Count;i++)
                        Card("PHASE "+(i+1)+" · "+(string)mechanics[i]["name"],
                            (string)raid["phases"]?[i]?["counter"]??"", "shield");
                    Text(navigationContent,"개발 사냥 화면에서는 패턴 정보를 확인합니다.",12).style.color=Muted;
                });
            }
        }
        void BuildBagNavigation()
        {
            var state=simulation.PlayerState?.Snapshot();var items=state?["loot_inventory"] as JArray;
            Text(navigationContent,"보유 장비 "+(items?.Count??0)+"개",14).style.color=Bronze;
            if(items==null||items.Count==0){Card("가방이 비어 있습니다","사냥에서 획득한 장비가 여기에 표시됩니다.","bag");return;}
            foreach(var item in items)
                Card((string)item["name"]??(string)item["base_name"]??"장비",
                    (string)item["slot"]??(string)item["type"]??"", "bag");
        }
        void BuildDungeonNavigation()
        {
            Card("일일 던전","전투 기능 준비 중", "dungeon");
            Card("시련의 탑","전투 기능 준비 중", "dungeon");
            Card("주간 도전","전투 기능 준비 중", "dungeon");
        }
    }
}
