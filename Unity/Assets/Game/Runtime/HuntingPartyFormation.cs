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
        // This is an editing draft. Live actors and the saved party are changed
        // only by the existing queued SetUnityParty command, at the next pack.
        sealed class PartyEditorDraft
        {
            public readonly List<string> Heroes=new List<string>();
            public string Formation,Role="전체",Sort="기본 순",Search="",Notice="";
            public int Selected=-1,Preset;
            public Vector2 Scroll;
        }
        bool PartyEditorCanEdit=>PersistentPlayer&&Raid==null&&ReviewState.MutationError.Length==0;
        static readonly Color PartyBlue=new Color(.20f,.48f,.78f);
        static readonly Color PartySurface=new Color(.075f,.12f,.19f);
        static readonly Color PartyEdge=new Color(.22f,.31f,.43f);

        static void PartyBorder(VisualElement element,Color color,int width=1)
        {
            element.style.borderTopWidth=element.style.borderBottomWidth=element.style.borderLeftWidth=element.style.borderRightWidth=width;
            element.style.borderTopColor=element.style.borderBottomColor=element.style.borderLeftColor=element.style.borderRightColor=color;
            element.style.borderTopLeftRadius=element.style.borderTopRightRadius=element.style.borderBottomLeftRadius=element.style.borderBottomRightRadius=9;
        }
        static void PartyInset(VisualElement element,int value)
        {element.style.paddingLeft=element.style.paddingRight=element.style.paddingTop=element.style.paddingBottom=value;}
        static Button PartyAction(VisualElement parent,string title,Action action,string name=null)
        {
            var button=Button(parent,title,action);button.name=name;button.style.marginLeft=0;button.style.marginRight=4;
            button.style.minWidth=0;button.style.height=34;button.style.fontSize=12;button.style.paddingLeft=button.style.paddingRight=7;
            button.style.flexGrow=1;button.style.flexBasis=0;return button;
        }
        static Label PartyCopy(VisualElement parent,string copy,int size=12)
        {
            var label=Text(parent,copy,size);label.style.marginTop=label.style.marginBottom=0;
            label.style.paddingTop=label.style.paddingBottom=0;label.style.minWidth=0;
            label.style.textOverflow=TextOverflow.Ellipsis;label.style.overflow=Overflow.Hidden;return label;
        }
        static string PartyPositionName(int slot)=>slot<3?"전열":slot<7?"중열":"후열";

        void BuildPlayerPartyEditor(PartyEditorDraft draft)
        {
            PanelHeader("영웅 편성");ConfigureInspection(InspectionLayout.Wide);
            Action redraw=()=>{};
            var message=PartyCopy(modal,draft.Notice.Length>0?draft.Notice:
                !PersistentPlayer?"미리보기 · 원정대 기록에서 편성을 저장할 수 있습니다.":
                Raid!=null?"레이드 진행 중 · 영웅을 살펴볼 수 있으며 편성은 레이드 종료 후 변경할 수 있습니다.":
                "편성 저장을 누르면 다음 무리부터 적용됩니다. 초상화를 눌러 두 영웅의 자리를 교체하세요.");
            message.name="party-editor-notice";message.style.whiteSpace=WhiteSpace.Normal;message.style.color=Moss;message.style.flexShrink=0;message.style.marginBottom=7;
            if(ReviewState.SavePending)
            {
                var retry=PartyAction(modal,"다시 저장",()=>
                {
                    if(ReviewState.RetrySave())
                    {
                        if(savePaused){Simulation.Paused=huntWasPaused;if(Raid!=null&&Raid.Running)Raid.Paused=raidWasPaused;}
                        savePaused=false;huntNotice="기록을 저장했습니다.";huntNoticeUntil=Time.unscaledTime+3;draft.Notice=huntNotice;
                    }
                    else draft.Notice="저장하지 못했습니다. 다시 저장해 주세요.";
                    BuildPlayerPartyEditor(draft);
                },"party-retry-save");retry.style.flexGrow=0;retry.style.flexBasis=StyleKeyword.Auto;retry.style.flexShrink=0;
            }
            var formations=(JObject)HuntingSimulation.Canonical["catalogs"]["formation"]["data"]["PROFILES"];
            var keys=formations.Properties().Select(p=>p.Name).ToList();
            var names=keys.Select(k=>(string)formations[k]["name"]).ToList();
            if(!keys.Contains(draft.Formation))draft.Formation=ReviewState.Formation;
            var body=Row(modal);body.name="party-editor-body";body.style.flexGrow=1;body.style.minHeight=0;body.style.minWidth=0;
            var left=new ScrollView{name="party-editor-left"};left.style.flexGrow=1;left.style.flexBasis=48;left.style.minWidth=0;left.style.minHeight=0;left.style.marginRight=12;body.Add(left);
            var right=new VisualElement{name="party-editor-right"};right.style.flexGrow=1;right.style.flexBasis=52;right.style.minWidth=0;right.style.minHeight=0;body.Add(right);

            var party=new VisualElement{name="party-layout-preview"};party.style.backgroundColor=PartySurface;PartyBorder(party,PartyEdge);PartyInset(party,9);left.Add(party);
            var title=Row(party);title.style.alignItems=Align.Center;title.style.marginBottom=7;
            PartyCopy(title,"출전 파티",18).style.flexGrow=1;
            var count=PartyCopy(title,"",15);count.name="party-editor-count";count.style.color=Bronze;
            var grid=new VisualElement{name="party-slot-grid"};party.Add(grid);
            var formation=new DropdownField("진형",names,Math.Max(0,keys.IndexOf(draft.Formation)));formation.name="party-formation";formation.AddToClassList("roster-filter");
            formation.labelElement.style.minWidth=42;formation.labelElement.style.width=42;formation.style.marginTop=8;formation.style.marginBottom=4;party.Add(formation);
            var description=PartyCopy(party,"");description.style.color=Moss;description.style.whiteSpace=WhiteSpace.Normal;

            var presetBar=Row(left);presetBar.name="party-preset-bar";presetBar.style.marginTop=8;presetBar.style.marginBottom=8;
            var presetButtons=new List<Button>();
            for(int i=0;i<3;i++)
            {
                int index=i;var preset=PartyAction(presetBar,"P"+(i+1),()=>
                {
                    if(!PartyEditorCanEdit)return;draft.Preset=index;
                    if(ReviewState.Snapshot()["unity_party_presets"]?[index.ToString()] is not JObject stored||stored["heroes"] is not JArray saved)
                    {draft.Notice="P"+(index+1)+"은 비어 있습니다. 현재 편성 저장으로 등록하세요.";redraw();return;}
                    var ids=saved.Values<string>().ToArray();string savedFormation=(string)stored["formation"];
                    if(ids.Length<1||ids.Length>10||ids.Distinct().Count()!=ids.Length||ids.Any(id=>!ReviewState.IsFactionHero(id))||!keys.Contains(savedFormation))
                    {draft.Notice="현재 진영에 맞는 편성을 다시 저장해 주세요.";redraw();return;}
                    draft.Heroes.Clear();draft.Heroes.AddRange(ids);draft.Formation=savedFormation;draft.Selected=-1;
                    formation.SetValueWithoutNotify(names[keys.IndexOf(savedFormation)]);
                    draft.Notice="P"+(index+1)+" 불러오기 완료 · 편성 저장을 누르면 다음 무리에 적용합니다.";redraw();
                },"party-preset-"+(i+1));presetButtons.Add(preset);
            }
            var savePreset=PartyAction(presetBar,"현재 편성 저장",()=>
            {
                if(!PartyEditorCanEdit)return;
                var result=ReviewState.SaveUnityPartyPreset(draft.Preset,draft.Heroes.ToArray(),draft.Formation);
                draft.Notice=result.Message;PauseForSaveFailure();BuildPlayerPartyEditor(draft);
            },"party-preset-save");savePreset.style.flexGrow=1.6f;

            var actionPanel=new VisualElement{name="party-action-panel"};actionPanel.style.backgroundColor=PartySurface;PartyBorder(actionPanel,PartyEdge);PartyInset(actionPanel,9);left.Add(actionPanel);
            var selectedLabel=PartyCopy(actionPanel,"",12);selectedLabel.name="party-selected-slot";selectedLabel.style.color=Bronze;selectedLabel.style.whiteSpace=WhiteSpace.Normal;selectedLabel.style.marginBottom=6;
            var reorder=Row(actionPanel);
            var forward=PartyAction(reorder,"앞으로",()=>Move(-1),"party-order-forward");
            var backward=PartyAction(reorder,"뒤로",()=>Move(1),"party-order-backward");
            var remove=PartyAction(reorder,"선택 해제",()=>
            {
                if(!PartyEditorCanEdit||draft.Selected<0||draft.Selected>=draft.Heroes.Count)return;
                draft.Heroes.RemoveAt(draft.Selected);draft.Selected=-1;redraw();
            },"party-remove-selected");
            var composition=PartyCopy(actionPanel,"",11);composition.name="party-composition";composition.style.color=Moss;composition.style.whiteSpace=WhiteSpace.Normal;composition.style.marginTop=7;
            var actions=Row(left);actions.style.marginTop=8;
            var auto=PartyAction(actions,"자동 편성",()=>
            {
                if(!PartyEditorCanEdit)return;var candidates=FilteredHeroes().Take(10).ToArray();
                if(candidates.Length==0){draft.Notice="현재 필터에 맞는 영웅이 없습니다.";redraw();return;}
                draft.Heroes.Clear();draft.Heroes.AddRange(candidates);draft.Selected=-1;draft.Notice="현재 필터와 정렬 순서로 편성했습니다. 저장하면 다음 무리에 적용됩니다.";redraw();
            },"party-auto");
            var clear=PartyAction(actions,"일괄 해제",()=>{if(!PartyEditorCanEdit)return;draft.Heroes.Clear();draft.Selected=-1;redraw();},"party-clear");
            var apply=PartyAction(actions,"편성 저장",()=>
            {
                if(!PartyEditorCanEdit)return;
                var result=ReviewState.SetUnityParty(draft.Heroes.ToArray(),draft.Formation);draft.Notice=result.Message;
                PauseForSaveFailure();BuildPlayerPartyEditor(draft);
            },"party-apply");apply.style.backgroundColor=Bronze;apply.style.color=Ink;
            var faction=PartyAction(left,"진영 선택 화면",()=>
            {
                if(ReviewState.SavePending){draft.Notice="먼저 다시 저장해 주세요.";redraw();return;}
                if(Raid!=null||!PersistentPlayer)return;
                new GameObject("Eternal faction selection").AddComponent<EternalBootstrap>();Destroy(gameObject);
            },"party-faction-selection");faction.style.marginTop=8;faction.style.flexGrow=0;faction.style.flexBasis=StyleKeyword.Auto;

            var filters=Row(right);filters.name="party-role-filters";filters.style.flexShrink=0;
            var roleButtons=new Dictionary<string,Button>();
            foreach(string role in new[]{"전체","딜러","탱커","서포터","컨트롤러"})
            {
                string selectedRole=role;roleButtons[role]=PartyAction(filters,role,()=>{draft.Role=selectedRole;draft.Scroll=Vector2.zero;redraw();},"party-role-"+role);
            }
            var toolsRow=Row(right);toolsRow.style.marginTop=7;toolsRow.style.marginBottom=6;toolsRow.style.alignItems=Align.Center;toolsRow.style.flexShrink=0;
            var rosterTitle=PartyCopy(toolsRow,"",15);rosterTitle.name="party-roster-count";rosterTitle.style.flexGrow=1;
            var sort=new DropdownField(new List<string>{"기본 순","레벨 순","등급 순","이름 순"},Math.Max(0,new[]{"기본 순","레벨 순","등급 순","이름 순"}.ToList().IndexOf(draft.Sort)));
            sort.name="party-roster-sort";sort.style.width=108;sort.style.fontSize=12;toolsRow.Add(sort);
            var search=new TextField{value=draft.Search,name="party-roster-search",label="검색"};search.AddToClassList("roster-filter");search.labelElement.style.minWidth=35;search.labelElement.style.width=35;search.style.marginBottom=7;right.Add(search);
            var roster=new ScrollView{name="party-roster-scroll"};roster.style.flexGrow=1;roster.style.minHeight=0;right.Add(roster);
            var rosterGrid=new VisualElement{name="party-roster-grid"};rosterGrid.style.flexDirection=FlexDirection.Row;rosterGrid.style.flexWrap=Wrap.Wrap;roster.Add(rosterGrid);
            roster.verticalScroller.valueChanged+=_=>draft.Scroll=roster.scrollOffset;
            var editControls=new[]{savePreset,auto,clear,apply,forward,backward,remove};

            IEnumerable<string> FilteredHeroes()
            {
                IEnumerable<string> heroes=Simulation.Catalog.HeroIds.Where(ReviewState.IsFactionHero).Where(id=>
                    (draft.Role=="전체"||(string)Simulation.Catalog.Hero(id)["role_group"]==draft.Role)&&
                    (draft.Search.Length==0||((string)Simulation.Catalog.Hero(id)["name"]??id).IndexOf(draft.Search,StringComparison.OrdinalIgnoreCase)>=0));
                return draft.Sort switch
                {
                    "레벨 순"=>heroes.OrderByDescending(id=>ReviewState.HeroProgress(id).level).ThenBy(id=>(string)Simulation.Catalog.Hero(id)["name"]),
                    "등급 순"=>heroes.OrderByDescending(id=>Array.IndexOf(new[]{"R","SR","SSR","UR"},ReviewState.Grade(id))).ThenByDescending(id=>ReviewState.HeroProgress(id).level),
                    "이름 순"=>heroes.OrderBy(id=>(string)Simulation.Catalog.Hero(id)["name"]),_=>heroes
                };
            }
            void Move(int delta)
            {
                int next=draft.Selected+delta;
                if(!PartyEditorCanEdit||draft.Selected<0||next<0||next>=draft.Heroes.Count)return;
                (draft.Heroes[draft.Selected],draft.Heroes[next])=(draft.Heroes[next],draft.Heroes[draft.Selected]);draft.Selected=next;redraw();
            }
            void Inspect(string id)
            {
                draft.Scroll=roster.scrollOffset;heroShowcaseReturn=()=>BuildPlayerPartyEditor(draft);ShowHeroShowcase(id,"growth");
            }
            void ToggleHero(string id)
            {
                if(!PartyEditorCanEdit)return;
                if(draft.Heroes.Contains(id))draft.Heroes.Remove(id);
                else if(draft.Heroes.Count<10)draft.Heroes.Add(id);
                else{draft.Notice="최대 10명까지 편성할 수 있습니다.";redraw();return;}
                draft.Selected=-1;redraw();
            }
            void DrawSlots()
            {
                grid.Clear();count.text=draft.Heroes.Count+" / 10명";
                for(int rowIndex=0;rowIndex<2;rowIndex++)
                {
                    var row=Row(grid);row.style.marginTop=rowIndex==0?0:6;
                    for(int column=0;column<5;column++)
                    {
                        int index=rowIndex*5+column;bool filled=index<draft.Heroes.Count;
                        var slot=new VisualElement{name="party-slot-"+index};slot.style.flexGrow=1;slot.style.flexBasis=0;slot.style.minWidth=0;slot.style.height=112;slot.style.marginRight=column==4?0:5;slot.style.backgroundColor=new Color(.09f,.15f,.24f);PartyBorder(slot,draft.Selected==index?Bronze:filled?PartyBlue:PartyEdge,draft.Selected==index?2:1);PartyInset(slot,4);row.Add(slot);
                        string id=filled?draft.Heroes[index]:null;
                        var portraitRow=Row(slot);portraitRow.style.height=61;portraitRow.style.flexShrink=0;
                        var pick=new Button(()=>
                        {
                            if(!PartyEditorCanEdit)return;
                            if(!filled){draft.Notice="오른쪽 영웅 목록의 편성 버튼으로 빈 자리를 채우세요.";search.Focus();redraw();return;}
                            if(draft.Selected<0)draft.Selected=index;
                            else if(draft.Selected==index)draft.Selected=-1;
                            else{(draft.Heroes[draft.Selected],draft.Heroes[index])=(draft.Heroes[index],draft.Heroes[draft.Selected]);draft.Selected=-1;}
                            redraw();
                        }){name="party-slot-select-"+index,tooltip=filled?(string)Simulation.Catalog.Hero(id)["name"]+" · 다른 출전 영웅을 눌러 자리 교체":"빈 자리"};
                        pick.style.flexGrow=1;pick.style.minWidth=0;pick.style.backgroundColor=Color.clear;pick.style.borderTopWidth=pick.style.borderBottomWidth=pick.style.borderLeftWidth=pick.style.borderRightWidth=0;PartyInset(pick,0);portraitRow.Add(pick);pick.SetEnabled(PartyEditorCanEdit);
                        if(filled)
                        {
                            var art=new Image{sprite=InspectionPortrait(id),scaleMode=ScaleMode.ScaleToFit,pickingMode=PickingMode.Ignore};art.style.height=57;art.style.width=Length.Percent(100);pick.Add(art);
                            var close=new Button(()=>ToggleHero(id)){text="×",name="party-slot-remove-"+id,tooltip="편성 해제"};close.style.width=24;close.style.minWidth=24;close.style.height=26;close.style.fontSize=18;close.style.backgroundColor=PartySurface;close.style.color=Parchment;PartyInset(close,0);portraitRow.Add(close);close.SetEnabled(PartyEditorCanEdit);
                        }
                        else{pick.text="+";pick.style.color=Moss;pick.style.fontSize=30;}
                        var name=PartyCopy(slot,filled?(string)Simulation.Catalog.Hero(id)["name"]:"빈 슬롯",12);name.style.unityTextAlign=TextAnchor.MiddleCenter;name.tooltip=name.text;
                        var level=PartyCopy(slot,(index+1)+" · "+PartyPositionName(index)+(filled?" · Lv"+ReviewState.HeroProgress(id).level:""),10);level.style.unityTextAlign=TextAnchor.MiddleCenter;level.style.color=Moss;
                    }
                }
            }
            void DrawRoster()
            {
                var offset=draft.Scroll;rosterGrid.Clear();var heroes=FilteredHeroes().ToArray();rosterTitle.text=draft.Role+" 영웅 · "+heroes.Length+"명";
                foreach(string id in heroes)
                {
                    string chosen=id;var hero=Simulation.Catalog.Hero(id);bool selected=draft.Heroes.Contains(id);
                    var card=new VisualElement{name="party-roster-card-"+id};card.style.width=Length.Percent(32);card.style.marginRight=Length.Percent(1);card.style.marginBottom=7;card.style.height=188;card.style.backgroundColor=PartySurface;PartyBorder(card,selected?Bronze:PartyEdge,selected?2:1);PartyInset(card,7);rosterGrid.Add(card);
                    var badges=Row(card);PartyCopy(badges,ReviewState.Grade(id),12).style.color=Bronze;
                    var level=PartyCopy(badges,"Lv."+ReviewState.HeroProgress(id).level,11);level.style.flexGrow=1;level.style.unityTextAlign=TextAnchor.MiddleRight;level.style.color=Moss;
                    var detail=new Button(()=>Inspect(chosen)){name="party-roster-detail-"+id,tooltip=(string)hero["name"]+" 상세 보기"};detail.style.height=79;detail.style.marginLeft=detail.style.marginRight=0;detail.style.backgroundColor=Color.clear;detail.style.borderTopWidth=detail.style.borderBottomWidth=detail.style.borderLeftWidth=detail.style.borderRightWidth=0;PartyInset(detail,0);card.Add(detail);
                    var image=new Image{sprite=InspectionPortrait(id),scaleMode=ScaleMode.ScaleToFit,pickingMode=PickingMode.Ignore};image.style.height=76;image.style.width=Length.Percent(100);detail.Add(image);
                    var name=PartyCopy(card,(string)hero["name"],13);name.style.unityTextAlign=TextAnchor.MiddleCenter;name.tooltip=name.text;
                    var role=PartyCopy(card,(string)hero["role_group"]+(selected?" · 출전":""),11);role.style.unityTextAlign=TextAnchor.MiddleCenter;role.style.color=selected?Bronze:Moss;
                    var deploy=PartyAction(card,selected?"해제":draft.Heroes.Count>=10?"인원 가득":"편성",()=>ToggleHero(chosen),"party-roster-toggle-"+id);deploy.style.flexGrow=0;deploy.style.flexBasis=StyleKeyword.Auto;deploy.style.marginTop=5;deploy.style.marginRight=0;deploy.style.height=29;deploy.style.backgroundColor=selected?new Color(.35f,.27f,.14f):PartyBlue;deploy.SetEnabled(PartyEditorCanEdit&&(selected||draft.Heroes.Count<10));
                }
                if(heroes.Length==0){var empty=PartyCopy(rosterGrid,"검색 조건에 맞는 영웅이 없습니다.",13);empty.style.marginTop=20;}
                roster.schedule.Execute(()=>roster.scrollOffset=offset);
            }
            void DrawAll()
            {
                if(draft.Selected>=draft.Heroes.Count)draft.Selected=-1;
                if(draft.Notice.Length>0)message.text=draft.Notice;
                DrawSlots();DrawRoster();description.text=HuntFormationLayout.Description(draft.Formation);
                selectedLabel.text=draft.Selected<0?"자리 교체 · 출전 영웅을 누른 뒤 다른 자리를 누르세요.":(draft.Selected+1)+"번 "+(string)Simulation.Catalog.Hero(draft.Heroes[draft.Selected])["name"]+" 선택 · 교체할 영웅을 누르세요.";
                composition.text="조합 · "+(string)ReviewState.PartySynergy(draft.Heroes)["summary"];
                var presets=ReviewState.Snapshot()["unity_party_presets"] as JObject;
                for(int i=0;i<presetButtons.Count;i++)
                {
                    int savedCount=(presets?[i.ToString()]?["heroes"] as JArray)?.Count??0;
                    presetButtons[i].text="P"+(i+1)+" · "+savedCount; presetButtons[i].style.backgroundColor=draft.Preset==i?PartyBlue:PartySurface;presetButtons[i].SetEnabled(PartyEditorCanEdit);
                }
                foreach(var item in roleButtons)item.Value.style.backgroundColor=draft.Role==item.Key?PartyBlue:PartySurface;
                foreach(var control in editControls)control.SetEnabled(PartyEditorCanEdit);
                apply.SetEnabled(PartyEditorCanEdit&&draft.Heroes.Count>0);savePreset.SetEnabled(PartyEditorCanEdit&&draft.Heroes.Count>0);
                forward.SetEnabled(PartyEditorCanEdit&&draft.Selected>0);backward.SetEnabled(PartyEditorCanEdit&&draft.Selected>=0&&draft.Selected+1<draft.Heroes.Count);remove.SetEnabled(PartyEditorCanEdit&&draft.Selected>=0);
                formation.SetEnabled(PartyEditorCanEdit);faction.SetEnabled(PersistentPlayer&&Raid==null&&!ReviewState.SavePending);
            }
            formation.RegisterValueChangedCallback(e=>{draft.Formation=keys[names.IndexOf(e.newValue)];redraw();});
            sort.RegisterValueChangedCallback(e=>{draft.Sort=e.newValue;draft.Scroll=Vector2.zero;DrawRoster();});
            search.RegisterValueChangedCallback(e=>{draft.Search=(e.newValue??"").Trim();draft.Scroll=Vector2.zero;DrawRoster();});
            redraw=DrawAll;redraw();
        }
    }
}
