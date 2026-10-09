using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;
using UnityEngine.UIElements;

namespace Eternal.UnityMigration
{
    // Development scene, not a replacement for production combat or its save.
    // The map and actors here are actual 3D meshes, not the generated concept.
    public sealed class RoyalGroveDevelopmentStage : MonoBehaviour
    {
        readonly List<AureliaVolumeActor> heroes=new();
        readonly List<GameObject> ownedObjects=new();
        Camera view;
        PanelSettings panel;
        string selected="leonhardt";
        Label heroName;
        VisualElement heroRail;
        float walkUntil;
        readonly Vector3[] homes={new(-2,0,0),new(0,0,1.3f),new(2,0,-.6f)};
        void Start()
        {
            var grove=Own("Royal grove authored volume");grove.AddComponent<RoyalGroveEnvironment>().Build();
            view=Own("Royal grove camera").AddComponent<Camera>();view.tag="MainCamera";view.orthographic=true;view.orthographicSize=17;
            view.transform.position=new Vector3(0,26,-31);view.transform.LookAt(new Vector3(0,0,3));view.backgroundColor=new Color(.13f,.19f,.22f);
            view.allowHDR=true;view.GetUniversalAdditionalCameraData().renderPostProcessing=true;view.gameObject.AddComponent<AudioListener>();
            var sun=Own("Warm grove sun").AddComponent<Light>();sun.type=LightType.Directional;sun.intensity=1.15f;sun.color=new Color(1,.94f,.83f);
            sun.transform.rotation=Quaternion.Euler(46,-33,0);sun.shadows=LightShadows.Soft;sun.shadowStrength=.75f;
            var fill=Own("Cool grove fill").AddComponent<Light>();fill.type=LightType.Directional;fill.intensity=.35f;fill.color=new Color(.56f,.76f,1);fill.transform.rotation=Quaternion.Euler(75,155,0);
            var atmosphere=Own("Grove atmosphere").AddComponent<Volume>();atmosphere.isGlobal=true;atmosphere.sharedProfile=Resources.Load<VolumeProfile>("Eternal/Materials/BattlePost");
            int index=0;foreach(string id in new[]{"leonhardt","elisia","mira"})
            {
                var actor=Own(id+" volume development").AddComponent<AureliaVolumeActor>();actor.transform.position=homes[index++];actor.transform.rotation=Quaternion.Euler(0,180,0);actor.Initialize(id);heroes.Add(actor);
            }
            BuildHud();
        }
        GameObject Own(string name){var go=new GameObject(name);ownedObjects.Add(go);return go;}
        void BuildHud()
        {
            panel=ScriptableObject.CreateInstance<PanelSettings>();panel.scaleMode=PanelScaleMode.ScaleWithScreenSize;panel.referenceResolution=new Vector2Int(1600,900);panel.match=.5f;
            panel.themeStyleSheet=Resources.Load<ThemeStyleSheet>("Eternal/UI/RuntimeTheme");var root=gameObject.AddComponent<UIDocument>().rootVisualElement;
            GetComponent<UIDocument>().panelSettings=panel;root=GetComponent<UIDocument>().rootVisualElement;
            root.style.flexGrow=1;root.style.unityFont=Resources.Load<Font>("Eternal/Fonts/EternalKR-Regular");root.style.color=new Color(.91f,.87f,.77f);
            var top=Plate(root,"grove-stage-header");top.style.position=Position.Absolute;top.style.top=14;top.style.left=18;top.style.width=410;top.style.height=62;
            var title=new Label("왕립 수림 · 아우렐리아");title.style.fontSize=21;top.Add(title);
            var state=new Label("3D 제작 단계 · 최종 그래픽 검수 전");state.style.fontSize=12;state.style.color=new Color(.66f,.72f,.62f);top.Add(state);
            heroRail=new VisualElement{name="grove-hero-rail"};heroRail.style.position=Position.Absolute;heroRail.style.right=18;heroRail.style.top=94;heroRail.style.width=134;heroRail.style.flexDirection=FlexDirection.Row;heroRail.style.flexWrap=Wrap.Wrap;root.Add(heroRail);
            for(int i=0;i<10;i++)
            {
                string id=i<heroes.Count?heroes[i].HeroId:null;
                var button=new Button(()=>{if(id!=null){selected=id;heroName.text=Name(id);}}){name="grove-hero-slot-"+i};Round(button,58);button.style.marginRight=8;button.style.marginBottom=10;
                button.style.backgroundColor=new Color(.035f,.055f,.070f,.85f);button.style.borderTopColor=button.style.borderBottomColor=button.style.borderLeftColor=button.style.borderRightColor=new Color(.68f,.52f,.29f);
                button.style.paddingLeft=button.style.paddingRight=button.style.paddingTop=button.style.paddingBottom=4;button.style.overflow=Overflow.Hidden;
                if(id!=null)
                {
                    // Original portrait belongs only in UI. World actors above
                    // use native skinned FBX and never use this texture.
                    var portrait=Resources.Load<Texture2D>("Eternal/GraphicsRebuild/Portraits/"+id);
                    if(portrait!=null){var image=new Image{image=portrait,scaleMode=ScaleMode.ScaleAndCrop};image.style.width=image.style.height=48;image.pickingMode=PickingMode.Ignore;button.Add(image);}
                    else button.text=Name(id).Substring(0,1);
                    button.tooltip=Name(id);
                }
                else{button.text="◇";button.SetEnabled(false);button.style.opacity=.45f;}
                heroRail.Add(button);
            }
            var identity=Plate(root,"grove-selected-hero");identity.style.position=Position.Absolute;identity.style.bottom=74;identity.style.left=Length.Percent(36);identity.style.width=275;identity.style.height=56;
            heroName=new Label(Name(selected));heroName.style.fontSize=18;identity.Add(heroName);var descriptor=new Label("입체 메시 · 뼈대 애니메이션 개발 중");descriptor.style.fontSize=11;identity.Add(descriptor);
            var zoom=new VisualElement{name="grove-zoom-controls"};zoom.style.position=Position.Absolute;zoom.style.bottom=86;zoom.style.right=274;zoom.style.flexDirection=FlexDirection.Row;root.Add(zoom);
            foreach(float factor in new[]{1f,1.5f,2f,3f})
            {
                float value=factor;var b=new Button(()=>view.orthographicSize=17/value){text="×"+value.ToString("0.#",System.Globalization.CultureInfo.InvariantCulture)};Round(b,40);b.style.marginRight=6;b.style.fontSize=12;zoom.Add(b);
            }
            var skills=new VisualElement{name="grove-skill-controls"};skills.style.position=Position.Absolute;skills.style.bottom=74;skills.style.right=18;skills.style.flexDirection=FlexDirection.Row;root.Add(skills);
            foreach(string label in new[]{"스킬 1","스킬 2","각성"})
            {
                var b=new Button(()=>{foreach(var actor in heroes)if(actor.HeroId==selected)actor.Attack();}){text=label};Round(b,66);b.style.marginLeft=8;b.style.fontSize=13;
                b.tooltip="개발 중: 기본 공격 애니메이션만 재생. 스킬 전투 판정·연출 연결 예정.";skills.Add(b);
            }
            var movement=new Button(()=>{walkUntil=Time.time+4;foreach(var actor in heroes)actor.Play("Walk");}){text="이동 동작"};Round(movement,86);movement.style.position=Position.Absolute;movement.style.left=28;movement.style.bottom=78;root.Add(movement);
            var nav=Plate(root,"grove-navigation");nav.style.position=Position.Absolute;nav.style.left=0;nav.style.right=0;nav.style.bottom=0;nav.style.height=48;nav.style.flexDirection=FlexDirection.Row;nav.style.justifyContent=Justify.Center;
            foreach(string label in new[]{"사냥","영웅","레이드","가방"})
            {
                var item=new Label(label);item.style.fontSize=16;item.style.width=180;item.style.unityTextAlign=TextAnchor.MiddleCenter;nav.Add(item);
            }
        }
        static string Name(string id)=>id=="leonhardt"?"레온하르트":id=="elisia"?"엘리시아":"미라 솔렌";
        static void Round(VisualElement e,float size)
        {e.style.width=e.style.height=size;e.style.minWidth=0;e.style.borderTopLeftRadius=e.style.borderTopRightRadius=e.style.borderBottomLeftRadius=e.style.borderBottomRightRadius=size/2;}
        static VisualElement Plate(VisualElement parent,string name)
        {
            var e=new VisualElement{name=name};e.style.backgroundColor=new Color(.035f,.055f,.070f,.85f);e.style.paddingLeft=e.style.paddingRight=12;e.style.paddingTop=e.style.paddingBottom=7;
            e.style.borderTopWidth=e.style.borderBottomWidth=1;e.style.borderTopColor=e.style.borderBottomColor=new Color(.57f,.44f,.27f);parent.Add(e);return e;
        }
        void Update()
        {
            if(walkUntil<=0)return;
            if(Time.time>=walkUntil){walkUntil=0;for(int i=0;i<heroes.Count;i++){heroes[i].transform.position=homes[i];heroes[i].Play("Idle");}return;}
            for(int i=0;i<heroes.Count;i++)heroes[i].transform.position=homes[i]+Vector3.right*Mathf.Sin((4-(walkUntil-Time.time))*Mathf.PI*.5f)*2;
        }
        void OnDestroy(){foreach(var go in ownedObjects)if(go!=null)Destroy(go);if(panel!=null)Destroy(panel);}
    }
}
