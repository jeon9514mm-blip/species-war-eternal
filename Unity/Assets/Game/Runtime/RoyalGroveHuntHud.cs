using System;
using System.Collections.Generic;
using System.Globalization;
using UnityEngine;
using UnityEngine.UIElements;

namespace Eternal.UnityMigration
{
    // A transparent, live combat overlay. Identity uses text while the native
    // map and hero models receive the graphics-development priority.
    public sealed partial class RoyalGroveHuntHud : MonoBehaviour
    {
        static readonly Color Ink=new(.028f,.040f,.053f,.88f),Bronze=new(.80f,.66f,.43f),Pale=new(.96f,.93f,.85f);
        static readonly Color Moss=new(.44f,.72f,.47f),Blue=new(.39f,.67f,.91f),Muted=new(.65f,.69f,.69f);
        static readonly string[] Slots={"a1","a2","ultimate"};
        readonly Dictionary<string,HeroTile> heroes=new();
        readonly Dictionary<string,SkillTile> skills=new();
        readonly Dictionary<string,(Button button,Label state)> automationButtons=new();
        HuntingSimulation simulation;
        RoyalHudBindings native;
        string partyKey="";
        CombatEncounter CurrentBattle=>native?.Battle?.Invoke()??simulation.Battle;
        bool CombatPaused=>native?.Paused?.Invoke()??simulation.Paused;
        bool PartyDefeated=>native?.Defeated?.Invoke()??simulation.Defeated;
        bool CombatFinished=>native?.Finished?.Invoke()??simulation.Defeated;
        bool ManualMoving=>native?.ManualMovement?.Invoke()??simulation.ManualMovementActive;
        bool InputAvailable=>native?.InputAllowed?.Invoke()??navigationRoute=="사냥";
        bool CanCast(string id,string slot)=>native?.CanCast?.Invoke(id,slot)??simulation.CanManualCast(id,slot);
        public void UseNativeBindings(RoyalHudBindings bindings){native=bindings??throw new ArgumentNullException(nameof(bindings));Refresh(selected);}
        public void SyncRoute(string route){navigationRoute=route=="도전"?"레이드":route;RefreshNavigation();}

        Action<string> select,cast;
        Action<Vector2> movement;
        Action stopMovement,resumeMovement,togglePause,restart;
        Action<float> zoom;
        Camera battleCamera;
        PanelSettings panel;
        UIDocument document;
        VisualElement root,safe,header,rail,identity,healthFill,ultimateFill,stick,knob,defeat,gemBadge,skillRow,zoomRow;
        Label stage,progress,gold,gems,heroName,hp,ultimate,noticeText,stickCaption,identityRole;
        Button pauseButton,zoomButton;
        Label identityInitial;
        Label identityLevel;
        Sigil pauseIcon,identityCrest;
        float stickSize=184;
        int pointer=-1;
        float currentZoom=1;
        string selected="";
        bool initialized,ownsFont;
        Font font;

        sealed class HeroTile
        {
            internal Button Button;
            internal VisualElement Health,Selection;
            internal Label Status;
        }
        sealed class SkillTile
        {
            internal Button Button;
            internal Label Title,State;
            internal Sigil Icon;
            internal VisualElement Shade,Fill;
        }

        public void Initialize(Camera camera,HuntingSimulation simulation,Action<string> select,Action<string> cast,
            Action<Vector2> movement,Action stopMovement,Action resumeMovement,Action<float> zoom,Action togglePause,Action restart)
        {
            if(initialized)throw new InvalidOperationException("Royal grove HUD is already initialized.");
            this.simulation=simulation??throw new ArgumentNullException(nameof(simulation));
            battleCamera=camera;this.select=select;this.cast=cast;this.movement=movement;this.stopMovement=stopMovement;
            this.resumeMovement=resumeMovement;this.zoom=zoom;this.togglePause=togglePause;this.restart=restart;
            panel=ScriptableObject.CreateInstance<PanelSettings>();panel.name="Royal grove compact hunting panel";
            panel.scaleMode=PanelScaleMode.ScaleWithScreenSize;panel.referenceResolution=new Vector2Int(1600,900);panel.match=1;
            panel.themeStyleSheet=Resources.Load<ThemeStyleSheet>("Eternal/UI/RuntimeTheme");
            document=gameObject.AddComponent<UIDocument>();document.panelSettings=panel;root=document.rootVisualElement;
            root.name="royal-grove-hunt-hud";root.style.flexGrow=1;root.pickingMode=PickingMode.Ignore;
            font=Resources.Load<Font>("Eternal/Fonts/EternalKR-Regular");
            if(font==null){font=Font.CreateDynamicFontFromOSFont(new[]{"Malgun Gothic","맑은 고딕","Arial"},16);ownsFont=true;}
            root.style.unityFont=font;root.style.color=Pale;root.style.fontSize=14;
            var sheet=Resources.Load<StyleSheet>("Eternal/UI/RoyalHunt");if(sheet!=null)root.styleSheets.Add(sheet);
            safe=new VisualElement{name="grove-safe-area",pickingMode=PickingMode.Ignore};Absolute(safe,0,0,0,0);root.Add(safe);
            BuildHeader();BuildHeroes();BuildIdentity();BuildSkills();BuildJoystick();BuildZoom();BuildOutcome();BuildNavigation();
            noticeText=Text(safe,"",14);noticeText.name="grove-battle-notice";noticeText.style.position=Position.Absolute;
            noticeText.style.top=84;noticeText.style.left=Length.Percent(28);noticeText.style.right=178;
            noticeText.style.unityTextAlign=TextAnchor.MiddleCenter;noticeText.style.whiteSpace=WhiteSpace.Normal;
            root.RegisterCallback<GeometryChangedEvent>(_=>LayoutSafeArea());
            initialized=true;Refresh(CurrentBattle.Heroes.Count>0?CurrentBattle.Heroes[0].Id:"");
        }

        void BuildHeader()
        {
            header=Plate(safe,"grove-hunt-title");header.style.position=Position.Absolute;header.style.left=18;header.style.top=14;
            header.style.width=455;header.style.height=53;header.style.paddingLeft=82;header.style.paddingTop=10;
            var medallion=new VisualElement{pickingMode=PickingMode.Ignore};Round(medallion,69);medallion.style.position=Position.Absolute;
            medallion.style.left=-5;medallion.style.top=-8;medallion.Add(new RoyalHudSurface(true,true));header.Add(medallion);
            var crest=new Sigil("crest",new Color(.96f,.83f,.59f));Absolute(crest,10,10,10,10);medallion.Add(crest);
            stage=Text(header,"",23);stage.name="grove-stage";stage.style.height=30;stage.style.unityFontStyleAndWeight=FontStyle.Bold;
            progress=Text(safe,"",12);progress.name="grove-wave-status";progress.style.position=Position.Absolute;
            progress.style.left=100;progress.style.top=72;progress.style.color=Muted;
            progress.style.backgroundColor=new Color(.025f,.034f,.044f,.70f);progress.style.paddingLeft=8;progress.style.paddingRight=8;
            progress.style.paddingTop=3;progress.style.paddingBottom=3;RoundCorners(progress,4);
            var caption=Text(safe,"개발 사냥 · 보상 미저장",11);caption.name="grove-development-caption";
            caption.style.position=Position.Absolute;caption.style.left=22;caption.style.top=94;caption.style.color=Muted;caption.style.fontSize=10;
            caption.style.display=DisplayStyle.None;
            var actions=Row(safe,"grove-top-actions");actions.style.position=Position.Absolute;actions.style.right=18;actions.style.top=16;
            gold=Currency(actions,"coin",Bronze,out _);gems=Currency(actions,"gem",Blue,out gemBadge);
            var chest=ActionButton(actions,"",()=>Navigate("가방"));chest.name="grove-top-bag";chest.style.width=50;
            var chestIcon=new GodotHudIcon("bag",Bronze);chestIcon.style.width=chestIcon.style.height=28;chest.Add(chestIcon);chest.tooltip="가방";
            pauseButton=ActionButton(actions,"일시정지",()=>{ReleaseStick();this.togglePause?.Invoke();Refresh(selected);});
            pauseButton.name="grove-pause";pauseButton.style.width=54;pauseButton.text="";
            var manage=ActionButton(actions,"≡",()=>{if(native?.Manage!=null)native.Manage();else Navigate("영웅");});manage.name="grove-manage";manage.style.width=38;manage.tooltip="원정대 메뉴";
            pauseIcon=new Sigil("pause",Pale);pauseIcon.style.width=pauseIcon.style.height=26;pauseButton.Add(pauseIcon);
        }

        Label Currency(VisualElement parent,string icon,Color color,out VisualElement badge)
        {
            badge=Plate(parent,"grove-currency-"+icon);badge.style.height=38;badge.style.minWidth=111;badge.style.paddingTop=4;badge.style.paddingBottom=4;
            badge.style.flexDirection=FlexDirection.Row;badge.style.alignItems=Align.Center;badge.style.marginRight=8;
            var glyph=new GodotHudIcon(icon,color);glyph.style.width=glyph.style.height=23;glyph.style.marginRight=6;badge.Add(glyph);
            var value=Text(badge,"",18);value.name="grove-"+icon+"-value";return value;
        }

        void BuildHeroes()
        {
            if(rail!=null){rail.RemoveFromHierarchy();heroes.Clear();}
            partyKey=string.Join("|",CurrentBattle.Heroes.ConvertAll(h=>h.Id));
            rail=Row(safe,"grove-hero-rail");rail.style.position=Position.Absolute;rail.style.right=18;rail.style.top=92;
            rail.style.width=164;rail.style.flexWrap=Wrap.Wrap;
            for(int i=0;i<10;i++)
            {
                string id=i<CurrentBattle.Heroes.Count?CurrentBattle.Heroes[i].Id:null;
                var container=new VisualElement{name="grove-hero-cell-"+i,pickingMode=PickingMode.Ignore};container.style.width=82;container.style.height=91;rail.Add(container);
                var button=new Button(()=>{if(id!=null){select?.Invoke(id);Refresh(id);}}){name="grove-hero-"+(id??"inactive-"+i)};
                CleanButton(button);Round(button,72);Border(button,Bronze,1.5f);button.style.backgroundColor=Ink;button.style.overflow=Overflow.Hidden;
                button.Add(new RoyalHudSurface(true,true));container.Add(button);
                if(id==null)
                {
                    var silhouette=new Sigil("empty",new Color(.35f,.40f,.42f));silhouette.style.width=34;silhouette.style.height=38;button.Add(silhouette);
                    button.SetEnabled(false);button.tooltip="미편성";button.style.opacity=.5f;continue;
                }
                var role=new Sigil(id=="leonhardt"?"leonhardt-a2":id+"-a1",id=="elisia"?Moss:id=="mira"?new Color(.95f,.58f,.40f):Blue);
                role.style.width=role.style.height=44;button.Add(role);
                var initial=Text(button,HeroName(id).Substring(0,1),10);initial.style.position=Position.Absolute;
                initial.style.bottom=5;initial.style.width=52;initial.style.unityTextAlign=TextAnchor.MiddleCenter;
                var selection=new VisualElement{pickingMode=PickingMode.Ignore};Absolute(selection,2,2,2,2);RoundCorners(selection,28);Border(selection,new Color(1,.85f,.46f),1);button.Add(selection);
                var track=Track(container,"grove-hero-hp-"+id,62,3);track.style.marginLeft=5;track.style.marginTop=4;
                var fill=Fill(track,Moss);var status=Text(container,"",10);status.style.width=62;status.style.height=12;status.style.unityTextAlign=TextAnchor.MiddleCenter;
                button.tooltip=HeroName(id);heroes[id]=new HeroTile{Button=button,Health=fill,Selection=selection,Status=status};
            }
        }

        void BuildIdentity()
        {
            identity=Plate(safe,"grove-selected-hero");identity.style.position=Position.Absolute;identity.style.left=Length.Percent(28);
            identity.style.bottom=99;identity.style.width=410;identity.style.height=84;identity.style.paddingLeft=86;identity.style.paddingRight=14;
            var portraitFrame=new VisualElement{pickingMode=PickingMode.Ignore};Round(portraitFrame,74);Border(portraitFrame,Bronze,2);
            portraitFrame.style.position=Position.Absolute;portraitFrame.style.left=2;portraitFrame.style.top=4;portraitFrame.style.overflow=Overflow.Hidden;
            portraitFrame.Add(new RoyalHudSurface(true,true));identityCrest=new Sigil("leonhardt-a2",Blue);
            identityCrest.style.width=identityCrest.style.height=48;portraitFrame.Add(identityCrest);
            identityInitial=Text(portraitFrame,"",11);identityInitial.style.position=Position.Absolute;identityInitial.style.bottom=7;
            identityInitial.style.width=68;identityInitial.style.unityTextAlign=TextAnchor.MiddleCenter;
            identity.Add(portraitFrame);identityLevel=Text(identity,"",10);identityLevel.style.position=Position.Absolute;identityLevel.style.bottom=-1;
            identityLevel.style.left=4;identityLevel.style.width=70;identityLevel.style.unityTextAlign=TextAnchor.MiddleCenter;
            var nameRow=Row(identity,"grove-identity-title");nameRow.style.alignItems=Align.Center;
            nameRow.style.height=20;nameRow.style.flexShrink=0;
            heroName=Text(nameRow,"",19);heroName.style.flexGrow=1;heroName.name="grove-selected-name";heroName.style.unityFontStyleAndWeight=FontStyle.Bold;
            identityRole=Text(nameRow,"",10);identityRole.style.color=Bronze;
            var health=Track(identity,"grove-selected-hp",0,20);health.style.width=Length.Percent(100);health.style.marginTop=7;RoundCorners(health,7);Border(health,Bronze,1);
            healthFill=Fill(health,Moss);var sheen=new VisualElement{pickingMode=PickingMode.Ignore};Absolute(sheen,1,1,1,10);sheen.style.backgroundColor=new Color(.72f,1,.76f,.24f);health.Add(sheen);
            hp=Text(health,"",13);Absolute(hp,0,0,0,0);hp.style.unityTextAlign=TextAnchor.MiddleCenter;hp.name="grove-selected-hp-value";
            var awaken=Track(identity,"grove-selected-ultimate",0,5);awaken.style.width=Length.Percent(100);awaken.style.marginTop=4;ultimateFill=Fill(awaken,Bronze);
            ultimate=Text(identity,"",10);ultimate.style.marginTop=1;ultimate.style.color=Muted;
        }

        void BuildSkills()
        {
            var row=Row(safe,"grove-skills");skillRow=row;row.style.position=Position.Absolute;row.style.right=18;row.style.bottom=94;
            foreach(string slot in Slots)
            {
                string captured=slot;var column=new VisualElement{pickingMode=PickingMode.Ignore};column.style.width=108;column.style.alignItems=Align.Center;row.Add(column);
                var button=new Button(()=>{if(CanCast(selected,captured))cast?.Invoke(captured);Refresh(selected);}){name="grove-cast-"+slot};
                CleanButton(button);Round(button,98);Border(button,Bronze,1);button.style.backgroundColor=Ink;button.style.overflow=Overflow.Hidden;
                button.Add(new RoyalHudSurface(true,true,slot=="a1"?new Color(.72f,.79f,.86f):Bronze));column.Add(button);
                var inner=new VisualElement{pickingMode=PickingMode.Ignore};Absolute(inner,5,5,5,5);RoundCorners(inner,35);Border(inner,new Color(.50f,.58f,.60f,.5f),1);button.Add(inner);
                var icon=new Sigil("crest",Pale);icon.style.width=70;icon.style.height=70;button.Add(icon);
                var shade=new VisualElement{pickingMode=PickingMode.Ignore};shade.style.position=Position.Absolute;shade.style.left=shade.style.right=shade.style.bottom=0;shade.style.height=0;
                shade.style.backgroundColor=new Color(.015f,.025f,.04f,.78f);button.Add(shade);
                var state=Text(button,"",15);Absolute(state,0,0,0,0);state.style.unityTextAlign=TextAnchor.MiddleCenter;
                var title=Text(column,"",16);title.style.width=104;title.style.height=24;title.style.marginTop=4;title.style.unityTextAlign=TextAnchor.MiddleCenter;
                title.style.overflow=Overflow.Hidden;title.style.textOverflow=TextOverflow.Ellipsis;
                var track=Track(column,"grove-skill-ready-"+slot,56,2);var fill=Fill(track,Bronze);
                skills[slot]=new SkillTile{Button=button,Title=title,State=state,Icon=icon,Shade=shade,Fill=fill};
            }
        }

        void BuildJoystick()
        {
            stick=new VisualElement{name="grove-movement-stick"};Round(stick,stickSize);Border(stick,new Color(.50f,.64f,.70f,.6f),2);
            stick.style.backgroundColor=new Color(.025f,.045f,.06f,.38f);stick.style.position=Position.Absolute;stick.style.left=32;stick.style.bottom=115;safe.Add(stick);
            stick.tooltip="드래그로 원정대를 이동합니다. 손을 떼면 정지하고 자동 사냥을 누르면 추적을 재개합니다.";
            var compass=new Sigil("compass",new Color(.72f,.79f,.81f,.65f));Absolute(compass,7,7,7,7);stick.Add(compass);
            knob=new VisualElement{name="grove-movement-knob",pickingMode=PickingMode.Ignore};Round(knob,66);Border(knob,new Color(.90f,.84f,.71f),2);
            knob.style.position=Position.Absolute;knob.style.left=knob.style.top=(stickSize-66)/2;knob.style.backgroundColor=new Color(.35f,.35f,.33f,.94f);
            knob.Add(new RoyalHudSurface(true,false,new Color(.86f,.82f,.71f),true));stick.Add(knob);
            stickCaption=Text(safe,"드래그 이동",11);stickCaption.style.position=Position.Absolute;stickCaption.style.left=32;stickCaption.style.bottom=96;
            stickCaption.style.width=184;stickCaption.style.unityTextAlign=TextAnchor.MiddleCenter;stickCaption.style.color=Muted;
            stick.RegisterCallback<PointerDownEvent>(e=>
            {
                if(pointer>=0||e.button!=0||!MovementEnabled())return;
                pointer=e.pointerId;stick.CapturePointer(pointer);ReadStick(e.localPosition);e.StopPropagation();
            });
            stick.RegisterCallback<PointerMoveEvent>(e=>{if(e.pointerId!=pointer)return;ReadStick(e.localPosition);e.StopPropagation();});
            stick.RegisterCallback<PointerUpEvent>(e=>{if(e.pointerId!=pointer)return;ReleaseStick();e.StopPropagation();});
            stick.RegisterCallback<PointerCancelEvent>(e=>{if(e.pointerId==pointer)ReleaseStick();});
            stick.RegisterCallback<PointerCaptureOutEvent>(e=>{if(e.pointerId==pointer)ReleaseStick();});
        }

        void BuildZoom()
        {
            var row=Row(safe,"grove-zoom");zoomRow=row;row.style.position=Position.Absolute;row.style.right=369;row.style.bottom=118;
            foreach(var item in new[]{("hunt","자동사냥"),("ultimate","각성기"),("skills","스킬")})
            {
                string channel=item.Item1;var button=new Button(()=>ToggleAutomation(channel)){name="grove-auto-"+channel};
                CleanButton(button);button.style.width=90;button.style.height=45;button.style.marginLeft=7;button.style.backgroundColor=Ink;RoundCorners(button,9);button.AddToClassList("royal-action");
                var title=Text(button,item.Item2,12);title.style.unityFontStyleAndWeight=FontStyle.Bold;
                var state=Text(button,"AUTO ON",11);state.style.marginTop=2;row.Add(button);automationButtons[channel]=(button,state);
            }
            zoomButton=new Button(CycleZoom){name="grove-zoom-cycle"};CleanButton(zoomButton);Round(zoomButton,45);Border(zoomButton,Bronze,1.5f);zoomButton.style.backgroundColor=Ink;zoomButton.style.marginLeft=8;zoomButton.style.fontSize=16;zoomButton.AddToClassList("royal-action");row.Add(zoomButton);
            RefreshZoom();
        }
        public void CycleZoom(){float[] factors={1f,1.5f,2f,3f};int index=Array.IndexOf(factors,currentZoom);SelectZoom(factors[(index+1)%factors.Length]);}
        public bool AutomationEnabled(string channel)=>channel=="skills"?CurrentBattle.SkillsAuto:channel=="ultimate"?CurrentBattle.UltimateAuto:CurrentBattle.HuntAuto&&!ManualMoving;
        public void ToggleAutomation(string channel)
        {
            if(!automationButtons.ContainsKey(channel)||!(native?.AutomationAllowed?.Invoke()??(!CombatFinished&&navigationRoute=="사냥")))return;
            bool enabled=!AutomationEnabled(channel);if(channel=="hunt")ReleaseStick();
            if(native?.SetAutomation!=null)native.SetAutomation(channel,enabled);
            else
            {
                if(simulation.PlayerState?.UnityPlayer==true&&!simulation.PlayerState.SetAutomationOption(channel,enabled).Ok)return;
                if(channel=="skills")CurrentBattle.SkillsAuto=enabled;else if(channel=="ultimate")CurrentBattle.UltimateAuto=enabled;else simulation.SetAutomaticHunt(enabled);
            }
            Refresh(selected);
        }

        void BuildOutcome()
        {
            defeat=Plate(safe,"grove-defeat");defeat.style.position=Position.Absolute;defeat.style.left=Length.Percent(38);defeat.style.top=Length.Percent(39);
            defeat.style.width=310;defeat.style.paddingTop=defeat.style.paddingBottom=16;defeat.style.alignItems=Align.Center;defeat.style.display=DisplayStyle.None;
            var title=Text(defeat,"원정대 전투 불능",21);title.style.color=Pale;
            var detail=Text(defeat,"대열을 정비하고 다시 출전합니다.",12);detail.style.marginTop=8;detail.style.color=Muted;
            var button=ActionButton(defeat,"다시 출전",()=>{ReleaseStick();restart?.Invoke();});button.name="grove-restart";button.style.width=150;button.style.marginTop=14;
        }

        public void Refresh(string selectedHeroId,string notice="")
        {
            if(!initialized)return;
            if(partyKey!=string.Join("|",CurrentBattle.Heroes.ConvertAll(h=>h.Id)))BuildHeroes();
            Combatant actor=null;foreach(var hero in CurrentBattle.Heroes)if(hero.Id==selectedHeroId){actor=hero;break;}
            if(actor==null&&CurrentBattle.Heroes.Count>0)actor=CurrentBattle.Heroes[0];
            selected=actor?.Id??"";
            int alive=0;foreach(var enemy in CurrentBattle.Enemies)if(enemy.Alive)alive++;
            stage.text=native?.Stage?.Invoke()??"왕립 수림   ·   "+simulation.Stage+" 스테이지";
            progress.text=native?.Progress?.Invoke()??"무리 "+(simulation.PacksCleared+1)+"  ·  남은 적 "+alive+(CombatPaused?"  ·  일시정지":simulation.NextPack>0?"  ·  다음 무리 진입":"  ·  교전 중");
            gold.text=(simulation.PlayerState?.WalletGold??simulation.Gold).ToString("N0",CultureInfo.InvariantCulture);
            gemBadge.style.display=simulation.PlayerState==null?DisplayStyle.None:DisplayStyle.Flex;
            if(simulation.PlayerState!=null)gems.text=simulation.PlayerState.WalletGems.ToString("N0",CultureInfo.InvariantCulture);
            pauseButton.tooltip=CombatPaused?"계속 사냥":"일시정지";pauseIcon.Set(CombatPaused?"play":"pause",Pale);pauseButton.SetEnabled(!CombatFinished&&InputAvailable);
            foreach(var item in automationButtons)
            {
                bool on=AutomationEnabled(item.Key);item.Value.state.text=on?"AUTO ON":"AUTO OFF";item.Value.state.style.color=on?Moss:Muted;
                Border(item.Value.button,on?Bronze:new Color(.36f,.41f,.43f),on?1.5f:1);item.Value.button.SetEnabled(native?.AutomationAllowed?.Invoke()??(!CombatFinished&&navigationRoute=="사냥"));
                item.Value.button.tooltip=(item.Key=="skills"?"일반 스킬":item.Key=="ultimate"?"각성기":"자동 추적·일반 공격")+" 자동 사용 "+(on?"켜짐":"꺼짐");
            }
            noticeText.text=notice??"";noticeText.style.display=string.IsNullOrWhiteSpace(notice)?DisplayStyle.None:DisplayStyle.Flex;
            defeat.style.display=PartyDefeated?DisplayStyle.Flex:DisplayStyle.None;
            foreach(var hero in CurrentBattle.Heroes)
            {
                if(!heroes.TryGetValue(hero.Id,out var tile))continue;
                tile.Selection.style.display=hero.Id==selected?DisplayStyle.Flex:DisplayStyle.None;
                tile.Button.style.opacity=hero.Alive?1:.42f;tile.Health.style.width=Length.Percent(Mathf.Clamp01((float)hero.HpRatio)*100);
                tile.Status.text=!hero.Alive?"전투 불능":hero.Stun>0?"기절":hero.Ultimate>=100?"각성 준비":"";
                tile.Status.style.color=hero.Ultimate>=100?Bronze:Muted;
            }
            identity.style.display=actor==null?DisplayStyle.None:DisplayStyle.Flex;
            if(actor!=null)
            {
                heroName.text=HeroName(actor.Id);identityRole.text=actor.Role;
                identityInitial.text=HeroName(actor.Id).Substring(0,1);
                identityCrest.Set(actor.Id=="leonhardt"?"leonhardt-a2":actor.Id+"-a1",actor.Id=="elisia"?Moss:actor.Id=="mira"?new Color(.94f,.58f,.41f):Blue);
                identityLevel.text="Lv."+(simulation.PlayerState?.HeroProgress(actor.Id).level??1);
                healthFill.style.width=Length.Percent(Mathf.Clamp01((float)actor.HpRatio)*100);
                healthFill.style.backgroundColor=actor.HpRatio<.25?new Color(.80f,.30f,.25f):Moss;
                hp.text=Math.Max(0,actor.Hp).ToString("N0")+" / "+actor.MaxHp.ToString("N0");
                ultimateFill.style.width=Length.Percent(Mathf.Clamp01((float)actor.Ultimate/100)*100);
                ultimate.text="각성 "+Mathf.Clamp((int)actor.Ultimate,0,100)+"%"+(actor.Shield>0?"  ·  보호막 "+actor.Shield.ToString("N0"):"");
            }
            foreach(string slot in Slots)RefreshSkill(actor,slot);
            bool moveEnabled=MovementEnabled();if(!moveEnabled)ReleaseStick();stick.SetEnabled(moveEnabled);stick.style.opacity=moveEnabled?1:.4f;
            stickCaption.text=ManualMoving?"직접 이동 · 놓으면 정지":"드래그 이동";
            SetCombatVisibility();
        }

        public void BindSimulation(HuntingSimulation next)
        {
            if(next==null)throw new ArgumentNullException(nameof(next));
            if(ReferenceEquals(simulation,next))return;
            ReleaseStick();simulation=next;
            if(initialized&&partyKey!=string.Join("|",CurrentBattle.Heroes.ConvertAll(h=>h.Id)))BuildHeroes();
        }

        void RefreshSkill(Combatant actor,string slot)
        {
            var tile=skills[slot];
            if(actor==null||!CurrentBattle.Kits.TryGetValue(actor.Id,out var kit)||!kit.Profiles.TryGetValue(slot,out var profile))
            {tile.Button.SetEnabled(false);tile.Title.text="";tile.State.text="—";return;}
            string name=(string)profile["skill"]??(slot=="ultimate"?"각성":slot=="a1"?"스킬 1":"스킬 2");
            double cooldown=kit.Cooldowns.TryGetValue(slot,out var remaining)?Math.Max(0,remaining):0;
            bool awakening=slot=="ultimate",ready=CanCast(actor.Id,slot);
            float completion=awakening?Mathf.Clamp01((float)actor.Ultimate/100):1-Mathf.Clamp01((float)(cooldown/Math.Max(.01,LegacyCombatRules.Number(profile,"cooldown",7))));
            tile.Button.SetEnabled(ready);tile.Button.style.opacity=!actor.Alive?.45f:1;
            tile.Title.text=awakening?"각성":slot=="a1"?"스킬 1":"스킬 2";tile.Button.tooltip=name+(awakening?" · 각성 게이지 100%":" · 재사용 "+LegacyCombatRules.Number(profile,"cooldown",7).ToString("0.#")+"초");
            tile.Icon.Set(actor.Id+"-"+slot,actor.Id=="elisia"?Moss:actor.Id=="mira"?new Color(.95f,.60f,.40f):awakening?Bronze:Blue);
            tile.Fill.style.width=Length.Percent(completion*100);tile.Shade.style.height=Length.Percent((1-completion)*100);
            tile.State.text=!actor.Alive?"불능":CombatPaused?"정지":actor.Stun>0?"기절":ready?"":awakening&&actor.Ultimate<100?((int)actor.Ultimate)+"%":cooldown>0?cooldown.ToString("0.0"):"대기";
            Border(tile.Button,ready?new Color(.94f,.78f,.44f):new Color(.42f,.44f,.44f),ready?2:1.5f);
        }

        bool MovementEnabled()=>simulation!=null&&!CombatPaused&&!CombatFinished&&battleCamera!=null&&InputAvailable;
        void ReadStick(Vector2 local)
        {
            if(!MovementEnabled()){ReleaseStick();return;}
            float center=stickSize/2,travel=(stickSize-66)/2-8;
            var offset=Vector2.ClampMagnitude((local-new Vector2(center,center))/travel,1);float length=offset.magnitude;
            offset=length<.10f?Vector2.zero:offset.normalized*((length-.10f)/.90f);
            knob.style.left=center-33+offset.x*travel;knob.style.top=center-33+offset.y*travel;
            // UI Toolkit has downward-positive y. The public callback is
            // normalized screen coordinates, upward-positive y, not world axes.
            movement?.Invoke(new Vector2(offset.x,-offset.y));
        }
        void ReleaseStick()
        {
            int captured=pointer;pointer=-1;
            if(captured>=0)stopMovement?.Invoke();
            if(stick!=null&&captured>=0&&stick.HasPointerCapture(captured))stick.ReleasePointer(captured);
            if(knob!=null)knob.style.left=knob.style.top=(stickSize-66)/2;
        }
        public void SelectZoom(float value)
        {
            if(value!=1&&value!=1.5f&&value!=2&&value!=3)return;
            currentZoom=value;zoom?.Invoke(value);RefreshZoom();
        }
        void RefreshZoom()
        {
            if(zoomButton==null)return;zoomButton.text="×"+currentZoom.ToString("0.#",CultureInfo.InvariantCulture);zoomButton.style.color=Pale;
            zoomButton.tooltip="현재 "+zoomButton.text+" · 누를 때마다 ×1 → ×1.5 → ×2 → ×3 순환";
        }
        void LayoutSafeArea()
        {
            if(root==null||Screen.width<=0||Screen.height<=0)return;
            var rect=Screen.safeArea;float sx=root.resolvedStyle.width/Screen.width,sy=root.resolvedStyle.height/Screen.height;
            if(!float.IsFinite(sx)||!float.IsFinite(sy))return;
            safe.style.left=rect.xMin*sx;safe.style.right=(Screen.width-rect.xMax)*sx;
            safe.style.top=(Screen.height-rect.yMax)*sy;safe.style.bottom=rect.yMin*sy;
            bool narrow=rect.width*sx<1260;header.style.width=narrow?352:455;stage.style.fontSize=narrow?18:23;
            identity.style.width=narrow?310:410;identity.style.left=Length.Percent(narrow?23:28);
            stickSize=narrow?160:184;Round(stick,stickSize);if(pointer<0)ReleaseStick();
            zoomRow.style.bottom=rect.width*sx<1560?195:118;
            LayoutNavigation(rect.width*sx);
        }
        string HeroName(string id)=>(string)simulation.Catalog.Hero(id)["name"]??id;
        static Label Text(VisualElement parent,string value,int size)
        {var label=new Label(value){pickingMode=PickingMode.Ignore};label.style.fontSize=size;label.style.marginLeft=label.style.marginRight=label.style.marginTop=label.style.marginBottom=0;parent.Add(label);return label;}
        static VisualElement Row(VisualElement parent,string name)
        {var row=new VisualElement{name=name,pickingMode=PickingMode.Ignore};row.style.flexDirection=FlexDirection.Row;parent.Add(row);return row;}
        static VisualElement Plate(VisualElement parent,string name)
        {var box=new VisualElement{name=name,pickingMode=PickingMode.Ignore};box.style.position=Position.Relative;box.style.backgroundColor=Ink;box.style.paddingLeft=box.style.paddingRight=10;box.style.paddingTop=box.style.paddingBottom=6;RoundCorners(box,9);Border(box,new Color(.45f,.38f,.26f,.7f),1);box.Add(new RoyalHudSurface(false,true));parent.Add(box);return box;}
        static Button ActionButton(VisualElement parent,string text,Action action)
        {var button=new Button(action){text=text};CleanButton(button);button.AddToClassList("royal-action");button.style.height=42;button.style.marginLeft=7;button.style.fontSize=13;button.style.backgroundColor=Ink;RoundCorners(button,8);Border(button,Bronze,1);parent.Add(button);return button;}
        static VisualElement Track(VisualElement parent,string name,float width,float height)
        {var track=new VisualElement{name=name,pickingMode=PickingMode.Ignore};track.style.width=width;track.style.height=height;track.style.flexShrink=0;track.style.backgroundColor=new Color(.025f,.04f,.05f,.95f);track.style.overflow=Overflow.Hidden;RoundCorners(track,3);parent.Add(track);return track;}
        static VisualElement Fill(VisualElement parent,Color color)
        {var fill=new VisualElement{pickingMode=PickingMode.Ignore};fill.style.width=Length.Percent(100);fill.style.height=Length.Percent(100);fill.style.backgroundColor=color;parent.Add(fill);return fill;}
        static void CleanButton(Button button)
        {button.style.marginTop=button.style.marginBottom=button.style.marginLeft=button.style.marginRight=0;button.style.paddingLeft=button.style.paddingRight=button.style.paddingTop=button.style.paddingBottom=0;button.style.minWidth=button.style.minHeight=0;button.style.alignItems=Align.Center;button.style.justifyContent=Justify.Center;button.style.color=Pale;button.style.backgroundImage=StyleKeyword.None;}
        static void Round(VisualElement element,float size){element.style.width=element.style.height=size;element.style.flexShrink=0;RoundCorners(element,size*.5f);}
        static void RoundCorners(VisualElement element,float radius){element.style.borderTopLeftRadius=element.style.borderTopRightRadius=element.style.borderBottomLeftRadius=element.style.borderBottomRightRadius=radius;}
        static void Border(VisualElement element,Color color,float width){element.style.borderTopWidth=element.style.borderBottomWidth=element.style.borderLeftWidth=element.style.borderRightWidth=width;element.style.borderTopColor=element.style.borderBottomColor=element.style.borderLeftColor=element.style.borderRightColor=color;}
        static void Absolute(VisualElement e,float left,float top,float right,float bottom){e.style.position=Position.Absolute;e.style.left=left;e.style.top=top;e.style.right=right;e.style.bottom=bottom;}
        void OnApplicationFocus(bool focused){if(!focused)ReleaseStick();}
        void OnApplicationPause(bool paused){if(paused)ReleaseStick();}
        void OnDisable(){ReleaseStick();}
        void OnDestroy(){ReleaseStick();if(document!=null)Destroy(document);if(panel!=null)Destroy(panel);if(ownsFont&&font!=null)Destroy(font);}

        // Small, resolution-independent skill emblems, not a pasted concept UI.
        sealed class Sigil : VisualElement
        {
            string key;Color ink;
            internal Sigil(string key,Color ink){this.key=key;this.ink=ink;pickingMode=PickingMode.Ignore;generateVisualContent+=Draw;}
            internal void Set(string value,Color color){if(value==key&&color==ink)return;key=value;ink=color;MarkDirtyRepaint();}
            void Draw(MeshGenerationContext context)
            {
                float scale=Mathf.Min(contentRect.width,contentRect.height)/48;if(scale<=0)return;
                var p=context.painter2D;var origin=new Vector2((contentRect.width-48*scale)/2,(contentRect.height-48*scale)/2);p.strokeColor=ink;p.lineWidth=1.6f*scale;
                void Line(params float[] xy){p.BeginPath();p.MoveTo(origin+new Vector2(xy[0],xy[1])*scale);for(int i=2;i<xy.Length;i+=2)p.LineTo(origin+new Vector2(xy[i],xy[i+1])*scale);p.Stroke();}
                void Ring(float x,float y,float radius){p.BeginPath();for(int i=0;i<=36;i++){float angle=i*Mathf.PI/18;var at=origin+new Vector2(x+Mathf.Cos(angle)*radius,y+Mathf.Sin(angle)*radius)*scale;if(i==0)p.MoveTo(at);else p.LineTo(at);}p.Stroke();}
                if(key=="pause"){p.lineWidth=6*scale;Line(17,10,17,38);Line(31,10,31,38);return;}
                if(key=="play"){Line(16,8,38,24,16,40,16,8);return;}
                if(key=="compass"){p.lineWidth=.55f*scale;Line(22,5,24,2,26,5);Line(22,43,24,46,26,43);Line(5,22,2,24,5,26);Line(43,22,46,24,43,26);Ring(24,24,21);Ring(24,24,22.4f);return;}
                if(key=="empty"){Ring(24,15,7);Line(10,40,12,30,20,26,28,26,36,30,38,40);return;}
                if(key=="crest"||key.EndsWith("ultimate",StringComparison.Ordinal))
                {
                    Ring(24,24,17);Line(24,2,28,19,44,24,28,29,24,46,20,29,4,24,20,19,24,2);
                    Line(10,9,24,19,38,9,29,24,38,39,24,29,10,39,19,24,10,9);Ring(24,24,4);return;
                }
                if(key.StartsWith("elisia",StringComparison.Ordinal))
                {Line(24,43,24,17,18,11,24,4,30,11,24,17);Line(24,30,11,23,8,11,18,14,24,24);Line(24,34,37,25,41,14,29,19,24,28);Ring(24,11,3);return;}
                if(key.StartsWith("mira",StringComparison.Ordinal))
                {Line(12,5,27,12,33,24,27,36,12,43,20,24,12,5);Line(3,24,45,24,37,17);Line(45,24,37,31);Line(5,19,10,24,5,29);if(key.EndsWith("a2",StringComparison.Ordinal)){Line(6,13,38,13);Line(6,35,38,35);}return;}
                if(key.EndsWith("a2",StringComparison.Ordinal))
                {Line(24,4,41,11,38,29,32,38,24,44,16,38,10,29,7,11,24,4);Line(24,11,24,35);Line(15,21,33,21);Line(13,13,24,9,35,13);return;}
                Line(10,36,35,6,43,4,41,13,15,40);Line(9,27,22,39);Line(12,36,5,44);Line(4,39,9,44);Line(16,29,35,8);
            }
        }
    }
}
