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
        // Godot HeroShowcaseView: faction roster / original art / four detail tabs.
        string heroShowcaseId="",heroShowcaseTab="growth";
        Vector2 heroShowcaseRosterOffset,heroShowcaseDetailOffset;
        Action heroShowcaseReturn;
        static readonly string[] HeroShowcaseTabs={"growth","skills","equipment","ascension"};
        static readonly string[] HeroShowcaseTabNames={"성장","스킬","장비","승급 · 돌파"};

        void ShowHeroShowcase(string id,string tab=null)
        {
            if(string.IsNullOrEmpty(id)||!Simulation.Catalog.HeroIds.Contains(id))return;
            string nextTab=HeroShowcaseTabs.Contains(tab)?tab:heroShowcaseTab;
            if(modal.Q<ScrollView>("HeroRosterScroll") is ScrollView oldRoster)heroShowcaseRosterOffset=oldRoster.scrollOffset;
            bool samePage=heroShowcaseId==id&&heroShowcaseTab==nextTab;
            heroShowcaseDetailOffset=samePage&&modal.Q<ScrollView>("PortraitContentScroll") is ScrollView oldDetail?oldDetail.scrollOffset:Vector2.zero;
            heroShowcaseId=id;heroShowcaseTab=nextTab;
            var hero=Simulation.Catalog.Hero(id);bool owned=ReviewState.IsFactionHero(id);
            string faction=(string)hero["faction"];
            var bindings=new List<Action>();
            PanelHeader("영웅 · "+(faction=="aurelia"?"아우렐리아":"녹스페라"));
            ConfigureInspection(InspectionLayout.Wide);
            modal.AddToClassList("hero-showcase");

            var toolbar=Row(modal);toolbar.name="hero-showcase-toolbar";toolbar.style.flexShrink=0;toolbar.style.alignItems=Align.Center;toolbar.style.marginTop=4;toolbar.style.marginBottom=8;
            if(heroShowcaseReturn!=null)
            {
                var back=Button(toolbar,"편성으로",()=>{var action=heroShowcaseReturn;heroShowcaseReturn=null;action?.Invoke();});
                back.name="hero-showcase-return";back.style.marginLeft=0;
            }
            var wallet=ShowcaseText(toolbar,"",12,Moss);wallet.name="growth-wallet";wallet.style.flexGrow=1;
            bindings.Add(()=>wallet.text="골드 "+ReviewState.WalletGold.ToString("N0")+"   ·   젬 "+ReviewState.WalletGems.ToString("N0"));
            var formation=Button(toolbar,"원정대 편성",OpenShowcaseFormation);formation.name="HeroFormationAction";formation.style.marginRight=0;
            formation.SetEnabled(PersistentPlayer);

            var body=Row(modal);body.name="hero-showcase-body";body.style.flexGrow=1;body.style.minHeight=0;body.style.marginBottom=8;
            var rosterPanel=ShowcasePanel(body,"HeroRosterPanel");rosterPanel.AddToClassList("hero-roster-panel");rosterPanel.style.width=178;rosterPanel.style.flexShrink=0;rosterPanel.style.marginRight=12;
            var ids=Simulation.Catalog.HeroIds.Where(key=>(string)Simulation.Catalog.Hero(key)["faction"]==faction).ToArray();
            ShowcaseText(rosterPanel,"영웅 목록   "+ids.Length,13,Parchment).style.marginBottom=6;
            var roster=new ScrollView(ScrollViewMode.Vertical){name="HeroRosterScroll"};roster.style.flexGrow=1;roster.style.minHeight=0;roster.horizontalScrollerVisibility=ScrollerVisibility.Hidden;rosterPanel.Add(roster);
            var rosterCards=new List<Button>();
            foreach(string key in ids)
            {
                string selected=key;var entry=Simulation.Catalog.Hero(key);
                var card=new Button(()=>ShowHeroShowcase(selected,heroShowcaseTab)){name="HeroRoster_"+key,tooltip=(string)entry["name"]+" · "+(string)entry["role_group"]};
                card.AddToClassList("hero-showcase-roster-card");card.EnableInClassList("is-selected",key==id);
                card.style.flexDirection=FlexDirection.Row;card.style.alignItems=Align.Center;card.style.height=74;card.style.minHeight=74;card.style.flexShrink=0;card.style.marginBottom=6;card.style.marginLeft=card.style.marginRight=0;
                card.style.paddingLeft=card.style.paddingRight=5;card.style.paddingTop=card.style.paddingBottom=4;
                card.style.backgroundColor=key==id?new Color(.19f,.23f,.20f):Ink;card.style.borderLeftWidth=key==id?3:1;card.style.borderLeftColor=key==id?Bronze:Moss;
                var portrait=new Image{sprite=InspectionPortrait(key),scaleMode=ScaleMode.ScaleToFit,pickingMode=PickingMode.Ignore};portrait.style.width=48;portrait.style.height=62;portrait.style.flexShrink=0;card.Add(portrait);
                var words=new VisualElement{pickingMode=PickingMode.Ignore};words.style.flexGrow=1;words.style.minWidth=0;words.style.marginLeft=6;card.Add(words);
                var name=ShowcaseText(words,(string)entry["name"],13,Parchment);name.name="HeroRosterName_"+key;name.style.whiteSpace=WhiteSpace.NoWrap;name.style.overflow=Overflow.Hidden;name.style.textOverflow=TextOverflow.Ellipsis;
                var level=ShowcaseText(words,"",11,Moss);level.name="hero-roster-level-"+key;
                bindings.Add(()=>level.text=ReviewState.IsFactionHero(selected)?"Lv."+ReviewState.HeroProgress(selected).level+(ReviewState.DeployedHeroes().Contains(selected)?" · 출전":""):(string)entry["role_group"]);
                roster.Add(card);rosterCards.Add(card);
            }

            var content=Row(body);content.name="hero-showcase-content";content.style.flexGrow=1;content.style.minWidth=0;content.style.minHeight=0;
            var artPanel=new VisualElement{name="HeroShowcaseArt"};artPanel.AddToClassList("hero-showcase-art");artPanel.style.flexGrow=1;artPanel.style.flexBasis=0;artPanel.style.minWidth=130;artPanel.style.minHeight=0;artPanel.style.marginRight=16;content.Add(artPanel);
            var grade=ShowcaseText(artPanel,"",25,Bronze);grade.name="HeroGradeValue";grade.style.flexShrink=0;
            bindings.Add(()=>grade.text=owned?ReviewState.Grade(id):"영웅 도감");
            var identity=ShowcaseText(artPanel,(string)hero["identity"]??(string)hero["class"],12,Moss);identity.style.flexShrink=0;
            var painting=new Image{name="HeroShowcaseActor",sprite=InspectionPortrait(id),scaleMode=ScaleMode.ScaleToFit,pickingMode=PickingMode.Ignore};painting.style.flexGrow=1;painting.style.minHeight=0;painting.style.width=Length.Percent(100);artPanel.Add(painting);
            var deployment=ShowcaseText(artPanel,"",13,Moss);deployment.name="HeroDeploymentState";deployment.style.unityTextAlign=TextAnchor.MiddleCenter;deployment.style.flexShrink=0;
            bindings.Add(()=>{int slot=ReviewState.DeployedHeroes().ToList().IndexOf(id);deployment.text=!owned?"다른 진영의 영웅":slot>=0?"출전 · "+(slot+1)+"번 자리":"미편성";});

            var information=ShowcasePanel(content,"HeroInformationPanel");information.AddToClassList("hero-information-panel");information.style.width=386;information.style.flexShrink=0;information.style.minHeight=0;
            ShowcaseText(information,(string)hero["name"],25,Parchment).name="HeroIdentityName";
            ShowcaseText(information,(string)hero["race"]+" · "+(string)hero["class"]+" · "+(string)hero["role_group"],12,Moss);
            var levelValue=ShowcaseText(information,"",15,Bronze);levelValue.name="HeroLevelValue";
            bindings.Add(()=>levelValue.text=owned?"LEVEL   "+ReviewState.HeroProgress(id).level+" / 100":((string)hero["reach"]=="melee"?"근접":"원거리")+" · 도감 열람");
            var tabs=Row(information);tabs.name="hero-showcase-tabs";tabs.style.flexShrink=0;tabs.style.marginTop=9;tabs.style.marginBottom=10;
            for(int index=0;index<HeroShowcaseTabs.Length;index++)
            {
                string selected=HeroShowcaseTabs[index];var button=Button(tabs,HeroShowcaseTabNames[index],()=>ShowHeroShowcase(id,selected));
                button.name="HeroTab_"+selected;button.AddToClassList("hero-showcase-tab");button.EnableInClassList("is-selected",selected==heroShowcaseTab);button.style.flexGrow=1;button.style.flexBasis=0;button.style.minWidth=0;button.style.height=39;button.style.marginLeft=0;button.style.marginRight=index==3?0:4;button.style.paddingLeft=button.style.paddingRight=2;button.style.fontSize=index==3?11:12;
                button.style.backgroundColor=selected==heroShowcaseTab?Bronze:Ink;button.style.color=selected==heroShowcaseTab?Ink:Parchment;
            }
            var detail=new ScrollView(ScrollViewMode.Vertical){name="PortraitContentScroll"};detail.style.flexGrow=1;detail.style.minHeight=0;detail.horizontalScrollerVisibility=ScrollerVisibility.Hidden;information.Add(detail);
            detail.contentContainer.style.paddingRight=6;
            if(!owned&&heroShowcaseTab!="skills")
            {
                ShowcaseText(detail,"다른 진영 영웅은 도감에서 기술과 전투 성향을 확인할 수 있습니다.",14,Moss);
                Button(detail,"스킬 보기",()=>ShowHeroShowcase(id,"skills")).style.marginLeft=0;
                ShowcaseSkills(detail,id,hero);
            }
            else if(heroShowcaseTab=="growth")ShowcaseGrowth(detail,id,bindings);
            else if(heroShowcaseTab=="skills")ShowcaseSkills(detail,id,hero);
            else if(heroShowcaseTab=="equipment")ShowcaseEquipment(detail,id,bindings);
            else ShowcaseAscension(detail,id,bindings);
            var status=ShowcaseText(information,"",11,Moss);status.name="growth-result";status.style.marginTop=7;status.style.flexShrink=0;
            bindings.Add(()=>
            {
                string error=Raid!=null?"레이드 중에는 성장과 편성을 바꿀 수 없습니다.":ReviewState.MutationError;
                status.text=error.Length>0?error:growthMessage;status.style.display=status.text.Length==0?DisplayStyle.None:DisplayStyle.Flex;
            });
            if(owned)
            {
                var deploy=Button(information,"",()=>QueueShowcaseDeployment(id));deploy.name="HeroDeployAction";deploy.style.marginLeft=deploy.style.marginRight=0;deploy.style.marginTop=8;deploy.style.height=40;deploy.style.flexShrink=0;
                bindings.Add(()=>
                {
                    var snapshot=ReviewState.Snapshot();var queued=snapshot["unity_next_party"] as JObject;
                    var chosen=queued?["heroes"] is JArray queuedIds?queuedIds.Values<string>().ToList():ReviewState.DeployedHeroes().ToList();bool included=chosen.Contains(id);
                    deploy.text=heroShowcaseReturn!=null?"편성에서 배치 변경":included?"배치 해제":"원정대에 배치";
                    deploy.tooltip=heroShowcaseReturn!=null?"편집 중인 원정대로 돌아갑니다.":queued!=null?"다음 무리 편성 예약에 반영합니다.":"다음 무리부터 새 편성을 적용합니다.";
                    deploy.SetEnabled(heroShowcaseReturn!=null||PersistentPlayer&&GrowthAllowed&&(included?chosen.Count>1:chosen.Count<10));
                });
            }
            BuildShowcaseParty(modal,id,bindings);
            // Keep live values current without rebuilding the tree beneath a drag or click.
            foreach(var update in bindings)update();
            information.schedule.Execute(()=>{if(modal.style.display.value==DisplayStyle.None)return;foreach(var update in bindings)update();}).Every(500);
            roster.schedule.Execute(()=>roster.scrollOffset=heroShowcaseRosterOffset);
            detail.schedule.Execute(()=>detail.scrollOffset=heroShowcaseDetailOffset);
            body.RegisterCallback<GeometryChangedEvent>(evt=>
            {
                float width=evt.newRect.width;bool narrow=width<730;
                body.style.flexDirection=narrow?FlexDirection.Column:FlexDirection.Row;
                rosterPanel.style.width=narrow?new StyleLength(Length.Percent(100)):new StyleLength(width<1020?145:178);
                rosterPanel.style.height=narrow?new StyleLength(110):new StyleLength(StyleKeyword.Auto);
                rosterPanel.style.marginRight=narrow?0:12;rosterPanel.style.marginBottom=narrow?8:0;
                roster.mode=narrow?ScrollViewMode.Horizontal:ScrollViewMode.Vertical;
                roster.horizontalScrollerVisibility=narrow?ScrollerVisibility.Auto:ScrollerVisibility.Hidden;roster.verticalScrollerVisibility=narrow?ScrollerVisibility.Hidden:ScrollerVisibility.Auto;
                roster.contentContainer.style.flexDirection=narrow?FlexDirection.Row:FlexDirection.Column;
                foreach(var card in rosterCards){card.style.width=narrow?new StyleLength(154):new StyleLength(Length.Percent(100));card.style.marginRight=narrow?6:0;}
                information.style.width=narrow?new StyleLength(Length.Percent(68)):new StyleLength(width<1020?330:386);
                artPanel.style.marginRight=narrow?8:16;artPanel.style.minWidth=narrow?80:130;
                painting.style.opacity=narrow?.94f:1f;
            });
        }

        void OpenShowcaseFormation()
        {
            if(heroShowcaseReturn!=null){var action=heroShowcaseReturn;heroShowcaseReturn=null;action();return;}
            if(PersistentPlayer)ShowPlayerParty();
        }
        void QueueShowcaseDeployment(string id)
        {
            if(heroShowcaseReturn!=null){OpenShowcaseFormation();return;}
            if(!PersistentPlayer||!ReviewState.IsFactionHero(id))return;
            var queued=ReviewState.Snapshot()["unity_next_party"] as JObject;
            var chosen=queued?["heroes"] is JArray ids?ids.Values<string>().ToList():ReviewState.DeployedHeroes().ToList();
            if(chosen.Contains(id))chosen.Remove(id);else chosen.Add(id);
            string formation=(string)queued?["formation"]??ReviewState.Formation;
            StateCommand(()=>ReviewState.SetUnityParty(chosen.ToArray(),formation),()=>ShowHeroShowcase(id));
        }
        void BuildShowcaseParty(VisualElement parent,string id,List<Action> bindings)
        {
            var footer=Row(parent);footer.name="hero-showcase-formation";footer.style.height=59;footer.style.flexShrink=0;footer.style.alignItems=Align.Center;
            var label=ShowcaseText(footer,"원정대",12,Moss);label.style.width=57;label.style.flexShrink=0;
            var party=new ScrollView(ScrollViewMode.Horizontal){name="growth-party-selector"};party.style.flexGrow=1;party.style.minWidth=0;party.style.height=58;party.horizontalScrollerVisibility=ScrollerVisibility.Auto;party.verticalScrollerVisibility=ScrollerVisibility.Hidden;party.contentContainer.style.flexDirection=FlexDirection.Row;footer.Add(party);
            string current="";
            void RefreshParty()
            {
                var heroes=ReviewState.DeployedHeroes();string signature=string.Join("|",heroes);if(signature==current&&party.childCount>0)return;current=signature;party.Clear();
                for(int index=0;index<10;index++)
                {
                    int slot=index;string selected=slot<heroes.Count?heroes[slot]:null;
                    var card=new Button(()=>{if(selected!=null)ShowHeroShowcase(selected,heroShowcaseTab);else OpenShowcaseFormation();}){name=selected!=null?"growth-select-"+selected:"hero-showcase-empty-"+slot,tooltip=selected!=null?(slot+1)+"번 · "+(string)Simulation.Catalog.Hero(selected)["name"]:"빈 자리 · 원정대 편성"};
                    card.style.width=44;card.style.height=48;card.style.flexShrink=0;card.style.marginTop=2;card.style.marginRight=5;card.style.paddingLeft=card.style.paddingRight=2;card.style.paddingTop=card.style.paddingBottom=2;card.style.backgroundColor=selected==id?Bronze:Ink;
                    if(selected!=null){var portrait=new Image{sprite=InspectionPortrait(selected),scaleMode=ScaleMode.ScaleToFit,pickingMode=PickingMode.Ignore};portrait.style.width=38;portrait.style.height=40;card.Add(portrait);}
                    else {card.text="+";card.style.fontSize=20;card.style.color=Moss;card.SetEnabled(PersistentPlayer);}
                    party.Add(card);
                }
                label.text="원정대\n"+heroes.Count+" / 10";
            }
            bindings.Add(RefreshParty);
        }
        void ShowcaseGrowth(VisualElement parent,string id,List<Action> bindings)
        {
            var stats=Row(parent);stats.name="HeroStatGrid";stats.style.marginBottom=8;
            foreach(var entry in new[]{("attack","공격력"),("defense","방어력"),("max_hp","체력")})
            {
                var block=ShowcasePanel(stats,"hero-stat-"+entry.Item1);block.style.flexGrow=1;block.style.flexBasis=0;block.style.minWidth=0;block.style.marginRight=5;
                ShowcaseText(block,entry.Item2,11,Moss);var value=ShowcaseText(block,"",18,Parchment);value.name="HeroStat_"+entry.Item1;
                bindings.Add(()=>{var heroes=ReviewState.DeployedHeroes();int slot=Math.Max(0,heroes.ToList().IndexOf(id));var profile=ReviewState.CombatProfile(id,slot,heroes);value.text=GameStateCommands.Integer(profile[entry.Item1],0,0,int.MaxValue).ToString("N0");});
            }
            ShowcaseText(parent,"장비 · 연구 · 진형 · 시너지 반영",11,Moss);
            var xp=ShowcaseText(parent,"",12,Moss);xp.name="HeroExperienceValue";xp.style.marginTop=10;
            var track=new VisualElement{name="growth-xp-track"};track.style.height=6;track.style.marginTop=4;track.style.marginBottom=15;track.style.backgroundColor=Ink;parent.Add(track);
            var fill=new VisualElement{name="growth-xp-fill"};fill.style.height=6;fill.style.backgroundColor=Moss;track.Add(fill);
            bindings.Add(()=>{var progress=ReviewState.HeroProgress(id);int required=LegacyGrowthEconomy.XpCost(progress.level,100);xp.text=progress.level>=100?"최대 레벨 달성":"EXP  "+progress.xp+" / "+required+" · 전투로 성장";fill.style.width=Length.Percent(progress.level>=100?100:Mathf.Clamp01((float)progress.xp/Math.Max(1,required))*100);});
            var points=ShowcaseText(parent,"",17,Parchment);points.name="HeroResearchPoints";bindings.Add(()=>points.text="성장 연구    "+ReviewState.HeroTree(id).available+" P 남음");
            foreach(string branch in new[]{"offense","survival","utility"})
            {
                string selected=branch;string name=branch=="offense"?"공격":branch=="survival"?"생존":"기능";
                int Rank(){var tree=ReviewState.HeroTree(id);return selected=="offense"?tree.offense:selected=="survival"?tree.survival:tree.utility;}
                var button=ShowcaseAction(parent,"",id,()=>ReviewState.UpgradeResearch(id,selected),()=>ReviewState.HeroTree(id).available>0&&Rank()<10,bindings);button.name="HeroResearch_"+selected;
                bindings.Add(()=>button.text=name+"   "+Rank()+" / 10     + 1 P");
            }
            ShowcaseText(parent,"영웅 레벨이 3 오를 때마다 연구 포인트를 얻어요.",12,Moss).style.marginTop=10;
        }
        void ShowcaseSkills(VisualElement parent,string id,JObject hero)
        {
            ShowcaseText(parent,"전투 기술 · 4종",16,Parchment).style.marginBottom=8;
            foreach(var skill in hero["skills"])
            {
                string slot=(string)skill["slot"];var block=ShowcasePanel(parent,"HeroSkill_"+slot);block.style.marginBottom=10;block.AddToClassList("hero-showcase-section");
                var row=Row(block);row.style.alignItems=Align.Center;
                if(PaintedHeroSigils.TryIcon(id,out var sigil,out var uv))
                {var icon=new Image{image=sigil,uv=uv,scaleMode=ScaleMode.ScaleToFit,pickingMode=PickingMode.Ignore};icon.style.width=40;icon.style.height=40;icon.style.marginRight=9;icon.style.flexShrink=0;row.Add(icon);}
                var heading=ShowcaseText(row,(string)skill["skill"],16,slot=="ultimate"?Bronze:Parchment);heading.style.flexGrow=1;heading.style.minWidth=0;
                string slotName=slot=="a1"?"액티브 1":slot=="a2"?"액티브 2":slot=="passive"?"패시브":"궁극기";
                ShowcaseText(block,slotName+" · "+(slot=="passive"?"조건 발동":slot=="ultimate"?"게이지 100%":skill["cooldown"]+"초"),11,Moss).style.marginTop=5;
                ShowcaseText(block,(string)skill["effect"],13,Parchment).style.marginTop=6;
            }
            ShowcaseText(parent,"전투 성향",16,Parchment);ShowcaseText(parent,(string)hero["identity_profile"]?["trait"],13,Moss);
        }
        void ShowcaseEquipment(VisualElement parent,string id,List<Action> bindings)
        {
            ShowcaseText(parent,"장착 중인 장비",17,Parchment).style.marginBottom=8;
            foreach(string slot in OriginalEquipmentRules.Slots)
            {
                string selected=slot;var block=ShowcasePanel(parent,"HeroGear_"+slot);block.AddToClassList("growth-gear-card");block.style.marginBottom=10;
                var name=ShowcaseText(block,"",14,Parchment);var detail=ShowcaseText(block,"",12,Moss);
                var enhance=ShowcaseAction(block,"",id,()=>{var item=ReviewState.EquippedItem(id,selected);return ReviewState.EnhanceGear((string)item["id"],id,selected);},()=>{var item=ReviewState.EquippedItem(id,selected);int level=(int)item["level"];return level<10&&ReviewState.WalletGold>=LegacyGrowthEconomy.EquipmentCost(selected,level);},bindings);
                enhance.name="hero-gear-enhance-"+slot;
                bindings.Add(()=>{var item=ReviewState.EquippedItem(id,selected);int level=(int)item["level"];name.text=SlotName(selected)+" · "+item["name"]+" +"+level;detail.text=item["rarity"]+" · "+item["set"]+" · 전투력 "+item["power"];enhance.text=level>=10?"최대 강화":"강화 · "+LegacyGrowthEconomy.EquipmentCost(selected,level).ToString("N0")+" 골드";});
            }
            var sets=ShowcaseText(parent,"",12,Moss);bindings.Add(()=>sets.text=(string)ReviewState.EquipmentProfile(id)["summary"]);
            var bag=Button(parent,"장비 가방에서 비교 · 교체",ShowInventory);bag.name="HeroEquipmentBag";bag.style.marginLeft=bag.style.marginRight=0;bag.style.marginTop=12;bag.style.height=42;
        }
        void ShowcaseAscension(VisualElement parent,string id,List<Action> bindings)
        {
            var grade=ShowcasePanel(parent,"hero-ascension-section");ShowcaseText(grade,"등급 승급",19,Parchment);var current=ShowcaseText(grade,"",16,Bronze);var requirement=ShowcaseText(grade,"",12,Moss);
            int Ascension()=> (int)GameStateCommands.Integer(ReviewState.Snapshot()["hero_ascension"]?[id],0,0,3);
            var ascend=ShowcaseAction(grade,"",id,()=>ReviewState.Ascend(id),()=>ReviewState.Grade(id)!="UR"&&ReviewState.HeroProgress(id).level>=10+Ascension()*10&&ReviewState.WalletGold>=1200+Ascension()*1800,bindings);ascend.name="HeroAscendAction";
            bindings.Add(()=>{bool capped=ReviewState.Grade(id)=="UR";int rank=Ascension(),cost=1200+rank*1800;current.text="현재 "+ReviewState.Grade(id)+(capped?" · 최고 등급":"");requirement.text=capped?"모든 등급 승급을 완료했습니다.":"필요 Lv."+(10+rank*10)+" · 골드 "+cost.ToString("N0");ascend.text=capped?"최고 등급 UR":"승급 · "+cost.ToString("N0")+" 골드";});
            var breakthrough=ShowcasePanel(parent,"hero-breakthrough-section");breakthrough.style.marginTop=12;ShowcaseText(breakthrough,"조각 돌파",19,Parchment);var shards=ShowcaseText(breakthrough,"",15,Bronze);shards.name="HeroShardBalance";
            int Rank()=> (int)GameStateCommands.Integer(ReviewState.Snapshot()["hero_breakthrough"]?[id],0,0,5);
            long Shards()=>GameStateCommands.Integer(ReviewState.Snapshot()["hero_shards"]?[id],0,0,GameStateCommands.CurrencyCap);
            var upgrade=ShowcaseAction(breakthrough,"",id,()=>ReviewState.Breakthrough(id),()=>Rank()<5&&Shards()>=20+Rank()*20,bindings);upgrade.name="HeroBreakthroughAction";
            bindings.Add(()=>{int rank=Rank();shards.text="돌파 "+rank+" / 5   ·   조각 "+Shards().ToString("N0")+"개 보유";upgrade.text=rank>=5?"최대 돌파":"돌파 · 조각 "+(20+rank*20)+"개";});
            var summon=Button(parent,"소환 · 조각 획득",ShowSummons);summon.name="HeroShardSource";summon.style.marginLeft=summon.style.marginRight=0;summon.style.marginTop=12;summon.style.height=42;
        }
        Button ShowcaseAction(VisualElement parent,string title,string id,Func<StateCommandResult> command,Func<bool> available,List<Action> bindings)
        {
            var button=Button(parent,title,()=>
            {
                if(!ReviewState.IsFactionHero(id)||!available())return;
                StateCommand(command,()=>ShowHeroShowcase(id));
            });
            button.style.marginLeft=button.style.marginRight=0;button.style.marginTop=7;button.style.height=39;button.style.flexShrink=0;
            bindings.Add(()=>button.SetEnabled(GrowthAllowed&&ReviewState.IsFactionHero(id)&&available()));return button;
        }
        static VisualElement ShowcasePanel(VisualElement parent,string name)
        {
            var panel=new VisualElement{name=name};panel.style.backgroundColor=new Color(.075f,.105f,.105f,.96f);panel.style.paddingLeft=panel.style.paddingRight=10;panel.style.paddingTop=panel.style.paddingBottom=10;
            panel.style.borderTopLeftRadius=panel.style.borderTopRightRadius=panel.style.borderBottomLeftRadius=panel.style.borderBottomRightRadius=10;parent.Add(panel);return panel;
        }
        static Label ShowcaseText(VisualElement parent,string value,int size,Color color)
        {
            var label=Text(parent,value??"",size);label.style.color=color;label.style.whiteSpace=WhiteSpace.Normal;label.style.marginTop=label.style.marginBottom=2;label.style.paddingTop=label.style.paddingBottom=0;label.style.flexShrink=0;return label;
        }
    }
}
