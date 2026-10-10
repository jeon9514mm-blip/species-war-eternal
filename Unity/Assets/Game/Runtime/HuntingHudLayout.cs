using System;
using UnityEngine;
using UnityEngine.UIElements;

namespace Eternal.UnityMigration
{
    public sealed partial class HuntingMigrationReview
    {
        VisualElement huntHeader,huntBattleSpace,huntDock;
        Button pauseHudButton,speedHudButton,chainHudButton;
        bool chainDeckExpanded;

        static void EllipsizeHud(Label label)
        {
            label.style.whiteSpace=WhiteSpace.NoWrap;label.style.overflow=Overflow.Hidden;
            label.style.textOverflow=TextOverflow.Ellipsis;label.style.minWidth=0;
        }
        static void RoundHud(VisualElement element,float radius)
        {
            element.style.borderTopLeftRadius=element.style.borderTopRightRadius=
                element.style.borderBottomLeftRadius=element.style.borderBottomRightRadius=radius;
        }
        Button CompactHudButton(VisualElement parent,string title,Action action,float width)
        {
            var button=Button(parent,title,action);button.style.width=width;button.style.minWidth=0;button.style.height=36;
            button.style.flexShrink=0;button.style.marginLeft=5;button.style.marginRight=0;
            button.style.paddingLeft=button.style.paddingRight=5;button.style.fontSize=13;return button;
        }
        static VisualElement HudTrack(VisualElement parent,string name,float height)
        {
            var track=new VisualElement{name=name,pickingMode=PickingMode.Ignore};track.style.height=height;track.style.flexShrink=0;
            track.style.minWidth=0;track.style.overflow=Overflow.Hidden;track.style.backgroundColor=new Color(.14f,.19f,.20f);
            parent.Add(track);return track;
        }
        static VisualElement HudFill(VisualElement parent,string name,Color color)
        {
            var fill=new VisualElement{name=name,pickingMode=PickingMode.Ignore};fill.style.height=Length.Percent(100);
            fill.style.width=Length.Percent(100);fill.style.maxWidth=Length.Percent(100);fill.style.backgroundColor=color;parent.Add(fill);return fill;
        }
        void ToggleChainDeck()
        {
            chainDeckExpanded=!chainDeckExpanded;RefreshHuntHudControls();RefreshChainStrip();
        }
        void RefreshHuntHudControls()
        {
            if(pauseHudButton==null)return;
            bool paused=Raid?.Paused??Simulation.Paused;pauseHudButton.text=paused?"사냥 재개":"일시정지";
            speedHudButton.text="×"+speed;
            chainHudButton.text=chainDeckExpanded?"연계 접기":"연계 펼치기";
            chainHudButton.tooltip=chainDeckExpanded?"수동 연계 스킬을 접어 전투 화면을 넓힙니다.":"수동 스킬 6칸과 연계 순서 설정을 펼칩니다.";
            chainStrip.style.visibility=chainDeckExpanded?Visibility.Visible:Visibility.Hidden;
            foreach(var icon in root.Query<GodotHudIcon>().ToList())icon.MarkDirtyRepaint();
            PositionHuntOverlays();
        }
        void ShowHuntControls()
        {
            PanelHeader("사냥 관리");ConfigureInspection(InspectionLayout.Sheet);
            var scroll=new ScrollView();scroll.style.flexGrow=1;scroll.style.minHeight=0;modal.Add(scroll);
            var intro=Text(scroll,"전투 설정과 빠른 성장",13);intro.style.color=Moss;intro.style.marginBottom=14;
            void AddControl(string title,string description,Action action)
            {
                var card=Box(scroll,"hunt-control",new Color(.085f,.12f,.13f));card.style.paddingLeft=card.style.paddingRight=12;
                card.style.paddingTop=card.style.paddingBottom=8;card.style.marginBottom=8;RoundHud(card,8);
                var line=Row(card);line.style.alignItems=Align.Center;
                var copy=Text(line,description,13);copy.style.flexGrow=1;copy.style.minWidth=0;copy.style.whiteSpace=WhiteSpace.Normal;
                var button=Button(line,title,action);button.style.width=115;button.style.flexShrink=0;
            }
            AddControl("빠른 성장","현재 원정대의 레벨 · 스킬 · 장비",()=>{if(Simulation.Battle.Heroes.Count>0)ShowGrowth(Simulation.Battle.Heroes[0].Id);});
            AddControl("장비 추천","보유 장비로 원정대 장착 추천",()=>
            {
                if(!GrowthAllowed)return;StateCommand(ReviewState.RecommendEquip,ShowHuntControls);huntNotice=growthMessage;huntNoticeUntil=Time.unscaledTime+3;RefreshHud();
            });
            if(playerSession!=null)
            {
                AddControl("사냥터","지역 이동과 사냥 진행 확인",ShowPlayerZones);
                AddControl("편성","최대 10인 원정대 편성",ShowPlayerParty);
                if(Simulation.Defeated)AddControl("다시 사냥","현재 사냥터에서 원정대 재정비",()=>RestartPlayerHunt(false));
            }
            AddControl("연계 순서","기존 자동 연계 순서 · 스킬 설정",ShowChain);
            AddControl("전체 메뉴","기록 · 보상 · 게임 설정",ShowStateMenu);
            var message=Text(scroll,growthMessage??"",12);message.style.color=Bronze;message.style.whiteSpace=WhiteSpace.Normal;
        }
        void BindHuntHudGeometry()
        {
            root.RegisterCallback<GeometryChangedEvent>(_=>PositionHuntOverlays());
            huntBattleSpace.RegisterCallback<GeometryChangedEvent>(_=>PositionHuntOverlays());
            huntDock.RegisterCallback<GeometryChangedEvent>(_=>PositionHuntOverlays());
            root.schedule.Execute(PositionHuntOverlays);
        }
        void PositionHuntOverlays()
        {
            if(huntBattleSpace==null||root==null||BattleCamera==null)return;
            Rect page=root.worldBound,field=huntBattleSpace.worldBound;
            if(float.IsNaN(page.width)||float.IsNaN(page.height)||float.IsNaN(field.width)||float.IsNaN(field.height)||page.width<=0||page.height<=0||field.width<=0||field.height<=0)return;
            float top=field.y-page.y,bottom=page.yMax-field.yMax;
            // The camera always uses the actual space left by the header/dock.
            // UI scaling, window aspect and resize cannot crop the party strip.
            float x=Mathf.Clamp01((field.x-page.x)/page.width),y=Mathf.Clamp01((page.yMax-field.yMax)/page.height);
            float width=Mathf.Clamp01(field.width/page.width),height=Mathf.Clamp01(field.height/page.height);
            BattleCamera.rect=new Rect(x,y,width,height);
            if(chainStrip!=null){chainStrip.style.left=18;chainStrip.style.right=18;chainStrip.style.bottom=bottom+7;}
            if(raidCommands!=null)
            {
                raidCommands.style.left=185;raidCommands.style.right=18;raidCommands.style.bottom=bottom+7;
                raidCommands.style.height=124;
                foreach(var button in raidCommands.Query<Button>().ToList())
                {button.style.minWidth=0;button.style.flexBasis=0;button.style.paddingLeft=button.style.paddingRight=4;button.style.fontSize=12;button.style.height=32;button.style.marginLeft=5;}
            }
            if(movementStick!=null)
            {
                movementStick.style.left=32;movementStick.style.bottom=bottom+(Raid!=null?37:chainDeckExpanded?87:37);
                huntFollowButton.style.left=150;huntFollowButton.style.bottom=bottom+(chainDeckExpanded?96:46);
            }
            if(huntMapTools!=null){huntMapTools.style.left=StyleKeyword.Auto;huntMapTools.style.right=18;huntMapTools.style.top=top+12;}
            if(raidPhaseRow!=null)raidPhaseRow.style.top=top+12;
            if(raidPhaseToast!=null)raidPhaseToast.style.top=top+43;
            if(raidMechanicTag!=null)raidMechanicTag.style.top=top+43;
            if(raidResolution!=null)raidResolution.style.top=top+43;
            if(castCue!=null)castCue.style.top=top+(Raid!=null?43:12);
            if(skillFeed!=null)skillFeed.style.top=top+(Raid!=null?133:107);
            if(responseCue!=null)responseCue.style.top=top+12;
            if(raidResult!=null)raidResult.style.top=top+Mathf.Max(8,(field.height-280)*.5f);
        }
    }

    // Paths ported from scripts/ui/GameUiIcon.gd, using the same 24-unit grid.
    // UI Toolkit Painter2D keeps the original menu marks crisp at any scale.
    internal sealed class GodotHudIcon : VisualElement
    {
        readonly string icon;
        readonly Color ink;
        readonly bool inheritColor;
        internal GodotHudIcon(string icon,Color ink,bool inheritColor=false)
        {
            this.icon=icon;this.ink=ink;this.inheritColor=inheritColor;pickingMode=PickingMode.Ignore;
            style.flexShrink=0;generateVisualContent+=Draw;
        }
        void Draw(MeshGenerationContext context)
        {
            var painter=context.painter2D;float scale=Mathf.Min(contentRect.width,contentRect.height)/24;
            if(scale<=0)return;Vector2 offset=new((contentRect.width-24*scale)/2,(contentRect.height-24*scale)/2);
            painter.strokeColor=inheritColor&&parent!=null?parent.resolvedStyle.color:ink;
            void Line(params float[] coordinates)
            {
                painter.lineWidth=1.7f*scale;painter.BeginPath();
                painter.MoveTo(offset+new Vector2(coordinates[0],coordinates[1])*scale);
                for(int i=2;i<coordinates.Length;i+=2)painter.LineTo(offset+new Vector2(coordinates[i],coordinates[i+1])*scale);
                painter.Stroke();
            }
            void Arc(float cx,float cy,float radius,float begin=0,float end=360)
            {
                var points=new float[50];for(int i=0;i<=24;i++){float angle=Mathf.Lerp(begin,end,i/24f)*Mathf.Deg2Rad;points[i*2]=cx+Mathf.Cos(angle)*radius;points[i*2+1]=cy+Mathf.Sin(angle)*radius;}Line(points);
            }
            switch(icon)
            {
                case "sword":Line(8,15,17,4,21,3,20,7,10,17);Line(6,13,12,19);Line(8,17,4,21);Line(3,19,5,21);break;
                case "hero":Arc(12,7.5f,3.5f);Arc(12,20,7,180,360);Line(5,20,19,20);Line(8.8f,3.7f,9.5f,1.8f,12,3.3f,14.5f,1.8f,15.2f,3.7f);break;
                case "shield":Line(12,3,20,6,19,14,16,18,12,21,8,18,5,14,4,6,12,3);Line(12,7,12,16);Line(8,11,16,11);break;
                case "bag":Line(5,8,19,8,20,20,4,20,5,8);Arc(12,8,4,180,360);Line(8,12,8,13);Line(16,12,16,13);Arc(12,13,4,8.6f,171.4f);break;
                case "raid":Line(3,3,18,18);Line(3,6,6,3);Line(2,18,18,2);Line(3,21,21,3);Line(2,14,9,21);Line(15,14,21,20);Line(14,17,17,14);break;
                case "dungeon":Line(3,21,3,8,7,8,7,3,17,3,17,8,21,8,21,21,3,21);Arc(12,14,4,180,360);Line(8,14,8,21);Line(16,14,16,21);Line(10,5,10,7);Line(14,5,14,7);break;
                case "hamburger":Line(3,5,21,5);Line(3,12,21,12);Line(3,19,21,19);break;
                case "coin":Arc(12,12,9);Arc(12,12,6);Line(12,7,15,12,12,17,9,12,12,7);break;
                case "gem":Line(6,4,18,4,22,9,12,21,2,9,6,4);Line(2,9,22,9);Line(8,4,7,9,12,21,17,9,16,4);break;
            }
        }
    }
}
