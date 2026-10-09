using System;
using System.Linq;
using UnityEngine;
using UnityEngine.UIElements;

namespace Eternal.UnityMigration
{
    public sealed partial class HuntingMigrationReview
    {
        // The shape, order and labels follow scripts/ui/LandscapeMainMenu.gd.
        // A route is enabled only when its native state/command implementation exists.
        void BuildLegacyMenu()
        {
            PanelHeader("전체 메뉴");
            ConfigureInspection(InspectionLayout.Drawer);
            modal.AddToClassList("legacy-menu-drawer");

            var header=modal.ElementAt(0);
            var quests=LegacyQuickAction(header,"quest","목표 · 업적",null,"목표·업적 기능 이관 중");
            quests.name="MenuQuickQuests";
            var rewards=LegacyQuickAction(header,"gift","보상 센터",ShowLegacyRewards);
            rewards.name="MenuQuickRewards";
            header.Insert(1,quests);header.Insert(2,rewards);

            var scroll=new ScrollView{name="legacy-menu-scroll"};
            scroll.style.flexGrow=1;scroll.style.minHeight=0;scroll.style.marginTop=16;
            scroll.horizontalScrollerVisibility=ScrollerVisibility.Hidden;
            modal.Add(scroll);

            var cards=Row(scroll);cards.name="MenuFeaturedCards";cards.AddToClassList("legacy-menu-features");
            cards.style.height=250;cards.style.flexShrink=0;cards.style.marginBottom=16;
            var war=LegacyFeature(cards,"war","종의 전쟁","진영 전투","",null,"전쟁 기능 이관 중");
            war.style.width=Length.Percent(18);war.style.marginRight=10;
            var right=new VisualElement();right.style.flexGrow=1;right.style.flexBasis=0;right.style.minWidth=0;cards.Add(right);
            var upper=Row(right);upper.style.height=120;upper.style.flexShrink=0;
            var camp=LegacyFeature(upper,"camp","원정 캠프","모험의 시작","Eternal/UI/expedition-key-art",ShowLegacyCamp);
            camp.style.flexGrow=1;camp.style.flexBasis=0;camp.style.marginRight=10;
            var world=LegacyFeature(upper,"world","사냥터","지역과 보상","Eternal/Environment/sky-court",ShowPlayerZones);
            world.style.flexGrow=1;world.style.flexBasis=0;
            var lower=Row(right);lower.style.height=120;lower.style.marginTop=10;lower.style.flexShrink=0;
            var summon=LegacyFeature(lower,"summon","소환","영웅과 수호령","",ShowSummons);
            var raid=LegacyFeature(lower,"raid","레이드","보스 토벌","Eternal/Environment/lunar-sanctum",()=>OpenPanel("도전"));
            var growth=LegacyFeature(lower,"growth","성장 · 던전","도전과 성장","",ShowLegacyGrowthHub);
            foreach(var card in new[]{summon,raid,growth}){card.style.flexGrow=1;card.style.flexBasis=0;card.style.minWidth=0;}
            summon.style.marginRight=10;raid.style.marginRight=10;

            var links=Row(scroll);links.name="MenuIconGrid";links.AddToClassList("legacy-menu-grid");
            links.style.flexWrap=Wrap.Wrap;links.style.flexShrink=0;
            LegacyMenuLink(links,"inventory","가방","bag",ShowInventory);
            LegacyMenuLink(links,"heroes","영웅","heroes",()=>OpenPanel("영웅"));
            LegacyMenuLink(links,"party","파티 편성","party",ShowPlayerParty);
            LegacyMenuLink(links,"formation","전투 진형","shield",ShowPlayerParty);
            LegacyMenuLink(links,"codex","영웅 도감","journal",ShowRoster);
            LegacyMenuLink(links,"training","성장 연구","growth",ShowLegacyResearch);
            LegacyMenuLink(links,"rewards","보상 센터","gift",ShowLegacyRewards);
            LegacyMenuLink(links,"quests","목표 · 업적","quest",null,"목표·업적 기능 이관 중");
            LegacyMenuLink(links,"market","거래소","coin",null,"거래 기능 이관 중");
            LegacyMenuLink(links,"faction","진영 선택","war",ReturnToLegacyEntry);
            LegacyMenuLink(links,"guide","가이드","compass",ShowLegacyGuide);
            LegacyMenuLink(links,"settings","설정","settings",ShowLegacySettings);

            if(ReviewState.SavePending)
            {
                var save=Button(scroll,"저장 대기 · 다시 저장",()=>RetryLegacySave(BuildLegacyMenu));
                save.name="legacy-menu-retry-save";save.style.marginLeft=0;save.style.marginTop=10;
                save.style.color=Bronze;save.style.flexShrink=0;
            }
            GrowthNotice(scroll);
            var footer=Row(modal);footer.name="MenuPreferences";footer.AddToClassList("legacy-menu-preferences");
            footer.style.flexShrink=0;footer.style.alignItems=Align.Center;footer.style.marginTop=12;footer.style.paddingTop=12;
            footer.style.borderTopWidth=1;footer.style.borderTopColor=new Color(.25f,.34f,.39f,.7f);
            BuildLegacyPreferenceToggles(footer);
            var space=new VisualElement();space.style.flexGrow=1;footer.Add(space);
            var title=Button(footer,"시작 화면",ReturnToLegacyEntry);title.name="PortraitMenu_title";
            title.style.height=42;title.SetEnabled(!ReviewState.SavePending);
            title.tooltip=ReviewState.SavePending?"기록을 다시 저장한 뒤 이동할 수 있습니다.":"진행 기록을 유지하고 시작 화면으로 이동합니다.";
        }

        Button LegacyQuickAction(VisualElement parent,string icon,string label,Action route,string reason="")
        {
            var button=new Button(route){tooltip=route==null?reason:label};button.AddToClassList("legacy-menu-quick");
            button.style.width=42;button.style.height=42;button.style.marginLeft=6;button.style.paddingLeft=button.style.paddingRight=7;
            button.style.paddingTop=button.style.paddingBottom=7;button.style.backgroundColor=Color.clear;
            button.style.borderLeftWidth=button.style.borderRightWidth=button.style.borderTopWidth=button.style.borderBottomWidth=0;
            var drawing=new LegacyMenuIcon(icon,Parchment);drawing.style.flexGrow=1;button.Add(drawing);
            button.SetEnabled(route!=null);parent.Add(button);return button;
        }

        Button LegacyFeature(VisualElement parent,string id,string title,string subtitle,string resource,Action route,string reason="")
        {
            var button=new Button(route){name="PortraitMenu_"+id,tooltip=route==null?reason:title+" · "+subtitle};
            button.AddToClassList("legacy-menu-feature");button.style.position=Position.Relative;button.style.minWidth=0;
            button.style.paddingLeft=button.style.paddingRight=button.style.paddingTop=button.style.paddingBottom=0;
            button.style.marginLeft=button.style.marginRight=button.style.marginTop=button.style.marginBottom=0;
            button.style.overflow=Overflow.Hidden;button.style.backgroundColor=new Color(.07f,.115f,.15f);
            button.style.borderLeftWidth=button.style.borderRightWidth=button.style.borderTopWidth=button.style.borderBottomWidth=1;
            button.style.borderLeftColor=button.style.borderRightColor=button.style.borderTopColor=button.style.borderBottomColor=new Color(.26f,.34f,.39f);
            button.style.borderTopLeftRadius=button.style.borderTopRightRadius=button.style.borderBottomLeftRadius=button.style.borderBottomRightRadius=5;
            parent.Add(button);
            var texture=string.IsNullOrEmpty(resource)?null:Resources.Load<Texture2D>(resource);
            if(texture==null&&id=="camp")texture=Resources.Load<Texture2D>("Eternal/Environment/Hunt/meadow-hunt-v1");
            if(texture!=null)
            {
                var art=new Image{image=texture,scaleMode=ScaleMode.ScaleAndCrop,pickingMode=PickingMode.Ignore};
                art.style.position=Position.Absolute;art.style.left=art.style.top=art.style.right=art.style.bottom=0;button.Add(art);
            }
            else
            {
                var emblem=new LegacyMenuIcon(id=="raid"?"war":id,Bronze);
                emblem.style.width=54;emblem.style.height=54;emblem.style.alignSelf=Align.Center;emblem.style.marginTop=id=="war"?46:5;
                button.Add(emblem);
            }
            var caption=new VisualElement();caption.pickingMode=PickingMode.Ignore;caption.style.position=Position.Absolute;
            caption.style.left=caption.style.right=caption.style.bottom=0;caption.style.paddingTop=7;caption.style.paddingBottom=8;
            caption.style.backgroundColor=new Color(.025f,.055f,.08f,.88f);button.Add(caption);
            var heading=Text(caption,title,19);heading.style.color=Parchment;heading.style.unityTextAlign=TextAnchor.MiddleCenter;
            heading.style.whiteSpace=WhiteSpace.Normal;heading.style.marginLeft=4;heading.style.marginRight=4;
            var detail=Text(caption,route==null?reason:subtitle,12);detail.style.color=route==null?Bronze:Moss;
            detail.style.unityTextAlign=TextAnchor.MiddleCenter;detail.style.whiteSpace=WhiteSpace.Normal;
            detail.style.marginTop=2;detail.style.marginLeft=4;detail.style.marginRight=4;
            button.SetEnabled(route!=null);return button;
        }

        void LegacyMenuLink(VisualElement parent,string id,string label,string icon,Action route,string reason="")
        {
            var button=new Button(route){name=id=="settings"?"PresentationSettingsEntry":id=="guide"?"PortraitOpenGuide":"PortraitMenu_"+id,tooltip=route==null?reason:label};
            button.AddToClassList("legacy-menu-link");button.style.width=Length.Percent(16.666f);button.style.height=92;
            button.style.marginLeft=button.style.marginRight=button.style.marginTop=button.style.marginBottom=0;
            button.style.paddingLeft=button.style.paddingRight=3;button.style.paddingTop=8;button.style.paddingBottom=4;
            button.style.backgroundColor=Color.clear;button.style.alignItems=Align.Center;button.style.justifyContent=Justify.FlexStart;
            button.style.borderLeftWidth=button.style.borderRightWidth=button.style.borderTopWidth=button.style.borderBottomWidth=0;
            parent.Add(button);
            var drawing=new LegacyMenuIcon(icon,Parchment);drawing.style.width=32;drawing.style.height=32;drawing.style.flexShrink=0;button.Add(drawing);
            var text=Text(button,label,14);text.style.unityTextAlign=TextAnchor.MiddleCenter;text.style.marginTop=6;text.style.whiteSpace=WhiteSpace.Normal;text.pickingMode=PickingMode.Ignore;
            if(route==null){var hint=Text(button,"이관 중",10);hint.style.color=Bronze;hint.style.marginTop=0;hint.pickingMode=PickingMode.Ignore;}
            button.SetEnabled(route!=null);
        }

        string LegacyFirstHero()=>ReviewState.DeployedHeroes().FirstOrDefault(ReviewState.IsFactionHero)??Simulation.Catalog.HeroIds.First(ReviewState.IsFactionHero);
        void ShowLegacyResearch()=>ShowHeroShowcase(LegacyFirstHero(),"growth");

        void ShowLegacyCamp()
        {
            PanelHeader("원정 캠프");var scroll=new ScrollView();scroll.style.flexGrow=1;modal.Add(scroll);
            LegacySection(scroll,ReviewState.Faction=="aurelia"?"아우렐리아 원정대":"녹스페라 원정대","영웅 "+ReviewState.DeployedHeroes().Count()+" / 10 · 원정대 Lv."+PlayerLevel());
            var synergy=Text(scroll,(string)ReviewState.PartySynergy()["summary"],13);synergy.style.whiteSpace=WhiteSpace.Normal;synergy.style.color=Moss;
            Button(scroll,"파티 편성 · 전투 진형",ShowPlayerParty).style.marginLeft=0;
            Button(scroll,"연계 순서",ShowChain).style.marginLeft=0;
            LegacySection(scroll,"현재 사냥터","스테이지 "+Simulation.Stage+" · "+HuntStageWorld.Atmosphere(Simulation.Stage));
            Button(scroll,"사냥터 정보",ShowPlayerZones).style.marginLeft=0;
            string guardian=(string)HuntingSimulation.Canonical["catalogs"]["guardian"]["data"]["DEFINITIONS"][ReviewState.EquippedGuardian]["name"];
            LegacySection(scroll,"장착 수호신",guardian);Button(scroll,"보유 수호신",ShowGuardians).style.marginLeft=0;
            LegacySection(scroll,"원정대 보상","골드 "+ReviewState.WalletGold.ToString("N0")+" · 젬 "+ReviewState.WalletGems.ToString("N0"));
            Button(scroll,"보상 센터",ShowLegacyRewards).style.marginLeft=0;
        }

        void ShowLegacyGrowthHub()
        {
            PanelHeader("성장 · 던전");var scroll=new ScrollView();scroll.style.flexGrow=1;modal.Add(scroll);
            LegacySection(scroll,"영웅 성장","연구 포인트 · 장비 강화 · 승급과 돌파");
            Button(scroll,"성장 연구",ShowLegacyResearch).style.marginLeft=0;
            Button(scroll,"수호신",ShowGuardians).style.marginLeft=0;
            LegacySection(scroll,"던전 도전","일일 던전 · 시련의 탑 · 주간 도전은 기능 이관 중입니다.");
            var pending=Button(scroll,"던전 도전 · 이관 중",null);pending.style.marginLeft=0;pending.SetEnabled(false);
            LegacySection(scroll,"레이드","보스 선택과 패턴 훈련을 이용할 수 있습니다.");
            Button(scroll,"레이드 입장",()=>OpenPanel("도전")).style.marginLeft=0;
        }

        void ShowLegacyRewards()
        {
            PanelHeader("보상 센터");var scroll=new ScrollView();scroll.style.flexGrow=1;modal.Add(scroll);
            LegacySection(scroll,"보유 재화","골드 "+ReviewState.WalletGold.ToString("N0")+" · 젬 "+ReviewState.WalletGems.ToString("N0"));
            GrowthNotice(scroll);
            var daily=GrowthButton(scroll,"일일 보상 · 젬 30 / 골드 100",()=>ReviewState.ClaimDaily(DateTime.Now.ToString("yyyy-MM-dd")),ShowLegacyRewards);
            daily.name="legacy-daily-reward";daily.style.marginTop=10;
            var snapshot=ReviewState.Snapshot();
            long gold=GameStateCommands.Integer(snapshot["unclaimed_gold"],0,0,GameStateCommands.CurrencyCap)+GameStateCommands.Integer(snapshot["idle_chest_gold"],0,0,GameStateCommands.CurrencyCap);
            long xp=GameStateCommands.Integer(snapshot["unclaimed_xp"],0,0,GameStateCommands.CurrencyCap)+GameStateCommands.Integer(snapshot["idle_chest_xp"],0,0,GameStateCommands.CurrencyCap);
            LegacySection(scroll,"보관 보상","골드 "+gold.ToString("N0")+" · 경험치 "+xp.ToString("N0"));
            var claim=GrowthButton(scroll,"보관 보상 수령",ReviewState.ClaimHuntingRewards,ShowLegacyRewards,gold>0||xp>0);claim.name="legacy-hunting-reward";
            if(PersistentPlayer)
            {
                LegacySection(scroll,"장비 보관함",ReviewState.UnityEquipmentMail().Count+"개 보관 · 가방 초과 장비 수령");
                Button(scroll,"장비 보관함",ShowUnityEquipmentMail).style.marginLeft=0;
            }
            if(ReviewState.SavePending)Button(scroll,"다시 저장",()=>RetryLegacySave(ShowLegacyRewards)).style.marginLeft=0;
            LegacySection(scroll,"사냥 기록","골드 "+Simulation.Gold.ToString("N0")+" · 경험치 "+Simulation.Xp.ToString("N0"));
        }

        static void LegacySection(VisualElement parent,string title,string description)
        {
            var heading=Text(parent,title,17);heading.style.color=Bronze;heading.style.marginTop=19;heading.style.marginBottom=6;
            var detail=Text(parent,description,13);detail.style.color=Moss;detail.style.whiteSpace=WhiteSpace.Normal;detail.style.marginBottom=10;
        }

        void RetryLegacySave(Action refresh)
        {
            if(ReviewState.RetrySave())
            {
                if(savePaused){Simulation.Paused=huntWasPaused;if(Raid!=null&&Raid.Running)Raid.Paused=raidWasPaused;}
                savePaused=false;growthMessage="기록을 저장했습니다.";huntNotice=growthMessage;huntNoticeUntil=Time.unscaledTime+3;
            }
            else growthMessage=ReviewState.SavePending?"저장하지 못했습니다. 다시 시도해 주세요.":"저장할 변경 내용이 없습니다.";
            refresh();RefreshHud();
        }

        void ReturnToLegacyEntry()
        {
            if(ReviewState.SavePending){growthMessage="먼저 기록을 다시 저장해 주세요.";BuildLegacyMenu();return;}
            new GameObject("Eternal faction selection").AddComponent<EternalBootstrap>();Destroy(gameObject);
        }

        void ShowLegacyGuide()
        {
            PanelHeader("가이드");var scroll=new ScrollView();scroll.style.flexGrow=1;modal.Add(scroll);
            LegacySection(scroll,"사냥","원정대가 자동으로 이동하며 전투합니다. 영웅칸을 누르면 영웅 성장·스킬·장비를 확인할 수 있습니다.");
            LegacySection(scroll,"파티 편성","같은 진영의 영웅을 최대 10명 편성합니다. 편성과 전투 진형 변경은 다음 무리부터 적용됩니다.");
            LegacySection(scroll,"도전","레이드에서 조이스틱으로 이동하고 카운터·무력화 지원을 사용하세요. 패턴 훈련은 임시 원정대로 진행하며 보상은 없습니다.");
            LegacySection(scroll,"가방과 보상","장비를 추천 장착하거나 잠금·강화·분해할 수 있습니다. 가방을 초과한 장비는 보관함에서 수령합니다.");
            LegacySection(scroll,"진행 기록",PersistentPlayer?"성장·장비·소환·편성은 현재 진영의 기록에 자동 저장됩니다. 저장 대기 표시가 나오면 메뉴에서 다시 저장하세요.":"현재는 플레이테스트입니다. 변경 사항은 이번 실행에만 유지되며 기존 저장 기록에는 반영되지 않습니다.");
            Button(scroll,"파티 편성",ShowPlayerParty).style.marginLeft=0;
        }

        void ShowLegacySettings()
        {
            PanelHeader("설정");var scroll=new ScrollView();scroll.style.flexGrow=1;modal.Add(scroll);
            LegacySection(scroll,"전투 연출과 소리","스킬의 장식 효과와 효과음을 설정합니다. 피해 숫자와 보스 위험 표시는 유지됩니다.");
            var preferences=Row(scroll);preferences.style.flexWrap=Wrap.Wrap;BuildLegacyPreferenceToggles(preferences);
            LegacySection(scroll,"스킬 연계","자동 연계 사용 여부와 스킬 순서를 바꿀 수 있습니다.");
            Button(scroll,"연계 순서",ShowChain).style.marginLeft=0;
            LegacySection(scroll,"진행 기록",ReviewState.SavePending?"저장 대기 중입니다. 기록을 다시 저장한 뒤 시작 화면으로 이동하세요.":PersistentPlayer?"진영별로 진행 기록을 자동 저장합니다.":"플레이테스트 기록은 이번 실행에서만 유지됩니다.");
            if(ReviewState.SavePending)Button(scroll,"다시 저장",()=>RetryLegacySave(ShowLegacySettings)).style.marginLeft=0;
            Button(scroll,"진영 선택 화면",ReturnToLegacyEntry).style.marginLeft=0;
        }

        void BuildLegacyPreferenceToggles(VisualElement parent)
        {
            // Presentation switches are wired by the common settings adapter;
            // neither control mutates combat or progression rules.
            var effects=new Toggle(SkillEffectsEnabled?"스킬 효과 ON":"스킬 효과 OFF"){name="PortraitEffectSetting",value=SkillEffectsEnabled,tooltip="스킬의 장식 효과를 설정합니다. 피해 숫자와 보스 위험 표시는 유지됩니다."};
            effects.RegisterValueChangedCallback(e=>{SetSkillEffectsEnabled(e.newValue);effects.label=e.newValue?"스킬 효과 ON":"스킬 효과 OFF";});
            var sound=new Toggle(SoundEffectsEnabled?"효과음 ON":"효과음 OFF"){name="PortraitSoundSetting",value=SoundEffectsEnabled};
            sound.RegisterValueChangedCallback(e=>{SetSoundEffectsEnabled(e.newValue);sound.label=e.newValue?"효과음 ON":"효과음 OFF";});
            foreach(var toggle in new[]{effects,sound})
            {toggle.style.fontSize=14;toggle.style.marginRight=16;toggle.style.height=40;toggle.style.alignItems=Align.Center;parent.Add(toggle);}
        }

        // Resolution-independent paths ported from GameUiIcon.gd. This avoids
        // platform-dependent emoji and keeps the original Godot icon silhouettes.
        internal sealed class LegacyMenuIcon : VisualElement
        {
            readonly string kind;readonly Color ink;
            public LegacyMenuIcon(string kind,Color ink)
            {this.kind=kind;this.ink=ink;pickingMode=PickingMode.Ignore;generateVisualContent+=Draw;}
            void Draw(MeshGenerationContext context)
            {
                float scale=Mathf.Min(contentRect.width,contentRect.height)/24f;if(scale<=0)return;
                Vector2 offset=contentRect.position+(contentRect.size-Vector2.one*24*scale)*.5f;
                var painter=context.painter2D;painter.strokeColor=ink;
                void Line(float[] xy,float width=1.7f)
                {
                    painter.lineWidth=width*scale;painter.BeginPath();painter.MoveTo(offset+new Vector2(xy[0],xy[1])*scale);
                    for(int i=2;i<xy.Length;i+=2)painter.LineTo(offset+new Vector2(xy[i],xy[i+1])*scale);painter.Stroke();
                }
                void Arc(float x,float y,float r,float start,float end)
                {
                    var points=new float[50];for(int i=0;i<25;i++){float a=Mathf.Lerp(start,end,i/24f);points[i*2]=x+Mathf.Cos(a)*r;points[i*2+1]=y+Mathf.Sin(a)*r;}Line(points);
                }
                void Circle(float x,float y,float r)=>Arc(x,y,r,0,Mathf.PI*2);
                switch(kind)
                {
                    case "home":case "camp":
                        Line(new float[]{3,10.5f,12,3,21,10.5f});Line(new float[]{5,9,5,20,10,20,10,14,14,14,14,20,19,20,19,9});break;
                    case "hero":case "heroes":case "party":
                        Circle(12,7.5f,3.5f);Arc(12,20,7,Mathf.PI,Mathf.PI*2);Line(new float[]{5,20,19,20});Line(new float[]{8.8f,3.7f,9.5f,1.8f,12,3.3f,14.5f,1.8f,15.2f,3.7f},1.3f);break;
                    case "growth":
                        Line(new float[]{5,20,5,15,8,15,8,20});Line(new float[]{11,20,11,11,14,11,14,20});Line(new float[]{17,20,17,7,20,7,20,20});Line(new float[]{4,10,11,5,17,3});Line(new float[]{13.5f,2.5f,18,2.5f,17.4f,6.5f});break;
                    case "inventory":case "bag":
                        Line(new float[]{5,8,19,8,20,20,4,20,5,8});Arc(12,8,4,Mathf.PI,Mathf.PI*2);Line(new float[]{8,12,8,13});Line(new float[]{16,12,16,13});Arc(12,13,4,.15f,Mathf.PI-.15f);break;
                    case "world":case "compass":
                        Circle(12,12,9);Line(new float[]{15.6f,7.2f,13.2f,13.4f,8.4f,16.8f,10.8f,10.6f,15.6f,7.2f});Line(new float[]{10.8f,10.6f,13.2f,13.4f},1.3f);break;
                    case "summon":
                        Line(new float[]{11,3,13.5f,9,20,11,13.5f,13.5f,11,20,8.5f,13.5f,2,11,8.5f,9,11,3});Line(new float[]{19,2,19,6},1.3f);Line(new float[]{17,4,21,4},1.3f);break;
                    case "settings":
                        Circle(12,12,6);Circle(12,12,2.2f);for(int i=0;i<8;i++){float a=Mathf.PI*2*i/8f;Line(new float[]{12+Mathf.Cos(a)*7,12+Mathf.Sin(a)*7,12+Mathf.Cos(a)*9.5f,12+Mathf.Sin(a)*9.5f},2.4f);}break;
                    case "quest":case "journal":
                        Line(new float[]{7,3,20,3,20,19,7,19,7,3});Line(new float[]{7,6,4,6,4,21,17,21,17,19});Line(new float[]{10,8,17,8});Line(new float[]{10,12,17,12});Line(new float[]{10,16,14,16});break;
                    case "war":case "battle":
                        Line(new float[]{8,15,17,4,21,3,20,7,10,17});Line(new float[]{6,13,12,19},2);Line(new float[]{8,17,4,21},2.5f);Line(new float[]{3,19,5,21},2);break;
                    case "shield":
                        Line(new float[]{12,3,20,6,19,14,16,18,12,21,8,18,5,14,4,6,12,3});Line(new float[]{12,7,12,16});Line(new float[]{8,11,16,11});break;
                    case "coin":
                        Circle(12,12,9);Circle(12,12,6);Line(new float[]{12,7,15,12,12,17,9,12,12,7},1.3f);break;
                    case "gift":
                        Line(new float[]{3,9,21,9,21,13,3,13,3,9});Line(new float[]{5,13,5,21,19,21,19,13});Line(new float[]{12,9,12,21});Circle(8.5f,6,3);Circle(15.5f,6,3);break;
                    case "close":
                        Line(new float[]{6,6,18,18},2);Line(new float[]{18,6,6,18},2);break;
                    case "hamburger":
                        Line(new float[]{3,5,21,5},2);Line(new float[]{3,12,21,12},2);Line(new float[]{3,19,21,19},2);break;
                    default:Circle(12,12,7);break;
                }
            }
        }
    }
}
