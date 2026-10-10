using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using Newtonsoft.Json.Linq;
using UnityEngine;
using UnityEngine.UIElements;

namespace Eternal.UnityMigration
{
    public sealed class EternalBootstrap : MonoBehaviour
    {
        public static string ProfileDirectoryOverride;
        public static string ProfileDirectory=>string.IsNullOrEmpty(ProfileDirectoryOverride)?Path.Combine(Application.persistentDataPath,"UnityProfiles-v1"):ProfileDirectoryOverride;
        readonly List<Sprite> portraits=new();
        OriginalCombatCatalog catalog;
        PanelSettings panel;
        Label message;
        TextField legacyPath;
        static readonly Color Ink=new(.035f,.055f,.065f,.97f),Bronze=new(.77f,.64f,.52f),Moss=new(.66f,.72f,.62f),Paper=new(.85f,.84f,.80f);
        void Start()
        {
            var view=new GameObject("Eternal entry camera");view.transform.SetParent(transform,false);var camera=view.AddComponent<Camera>();camera.clearFlags=CameraClearFlags.SolidColor;camera.backgroundColor=Ink;
            catalog=new OriginalCombatCatalog(OriginalCatalog.Required("hero-catalog").text);
            panel=ScriptableObject.CreateInstance<PanelSettings>();panel.scaleMode=PanelScaleMode.ScaleWithScreenSize;panel.referenceResolution=new Vector2Int(1600,900);panel.match=.5f;panel.themeStyleSheet=Resources.Load<ThemeStyleSheet>("Eternal/UI/RuntimeTheme");
            var document=gameObject.AddComponent<UIDocument>();document.panelSettings=panel;var root=document.rootVisualElement;
            var styles=Resources.Load<StyleSheet>("Eternal/UI/BattleUi");if(styles!=null)root.styleSheets.Add(styles);
            root.AddToClassList("entry-screen");root.style.flexGrow=1;root.style.color=Paper;root.style.unityFont=Resources.Load<Font>("Eternal/Fonts/EternalKR-Regular");root.style.alignItems=Align.Center;root.style.justifyContent=Justify.Center;
            var background=new Image{image=Resources.Load<Texture2D>("Eternal/Environment/sky-court"),scaleMode=ScaleMode.ScaleAndCrop,pickingMode=PickingMode.Ignore};
            background.style.position=Position.Absolute;background.style.left=background.style.right=background.style.top=background.style.bottom=0;background.style.opacity=.55f;root.Add(background);
            var plate=new VisualElement();plate.AddToClassList("entry-plate");plate.style.width=940;plate.style.maxWidth=Length.Percent(94);plate.style.maxHeight=Length.Percent(96);plate.style.paddingLeft=30;plate.style.paddingRight=30;plate.style.paddingTop=28;plate.style.paddingBottom=26;plate.style.backgroundColor=Ink;
            plate.style.borderTopWidth=plate.style.borderBottomWidth=1;plate.style.borderTopColor=plate.style.borderBottomColor=Bronze;root.Add(plate);
            Text(plate,"종의전쟁: 이터널",35,Bronze).style.unityTextAlign=TextAnchor.MiddleCenter;
            Text(plate,"30명의 영웅 · 10인 원정대 · 3개의 지역 레이드",14,Moss).style.unityTextAlign=TextAnchor.MiddleCenter;
            var choices=new VisualElement();choices.style.flexDirection=FlexDirection.Row;choices.style.marginTop=22;plate.Add(choices);
            foreach(string faction in new[]{"aurelia","noxfera"})
            {
                string selected=faction;var card=new VisualElement();card.style.flexGrow=1;card.style.flexBasis=0;card.style.marginLeft=8;card.style.marginRight=8;card.style.paddingLeft=16;card.style.paddingRight=16;card.style.paddingTop=10;card.style.paddingBottom=14;card.style.backgroundColor=new Color(.075f,.105f,.12f);card.AddToClassList("entry-faction-card");choices.Add(card);
                string hero=catalog.HeroIds.First(id=>(string)catalog.Hero(id)["faction"]==faction);var art=new Image{sprite=Portrait(hero),scaleMode=ScaleMode.ScaleToFit};art.style.height=210;art.style.flexShrink=1;card.Add(art);
                string title=faction=="aurelia"?"아우렐리아":"녹스페라";Text(card,title,22,Bronze).style.unityTextAlign=TextAnchor.MiddleCenter;
                Text(card,faction=="aurelia"?"빛의 원정대":"그림자의 원정대",13,Moss).style.unityTextAlign=TextAnchor.MiddleCenter;
                var store=new NativeSessionStore(NativeSessionStore.LatestPath(ProfileDirectory,faction),faction);var saved=store.Read();
                string status=saved.Ok?"저장된 원정대 이어하기":saved.Status=="missing"?"새 원정대 · Lv1 · 영웅 10인":"저장 기록 확인 필요";
                Text(card,status,12,Paper).style.unityTextAlign=TextAnchor.MiddleCenter;
                var begin=Button(card,title+(saved.Ok?" 이어하기":" 시작"),()=>Begin(selected));begin.name="start-"+selected;begin.SetEnabled(saved.Ok||saved.Status=="missing");
            }
            message=Text(plate,"진영마다 진행 기록을 따로 저장합니다.",13,Moss);message.style.unityTextAlign=TextAnchor.MiddleCenter;message.style.whiteSpace=WhiteSpace.Normal;message.style.marginTop=16;
            var importFoldout=new Foldout{text="기존 기록 가져오기",value=false};importFoldout.style.marginTop=12;plate.Add(importFoldout);
            var import=new VisualElement();import.style.flexDirection=FlexDirection.Row;import.style.alignItems=Align.Center;import.style.marginTop=16;importFoldout.Add(import);
            legacyPath=new TextField("기존 기록 파일");legacyPath.style.flexGrow=1;legacyPath.labelElement.style.minWidth=100;legacyPath.labelElement.style.width=100;import.Add(legacyPath);
            Button(import,"기록 가져오기",ImportLegacy).style.marginLeft=10;
            var importHelp=Text(importFoldout,"기존 기록은 그대로 보존하고 별도 기록으로 가져옵니다.",12,Moss);importHelp.style.whiteSpace=WhiteSpace.Normal;importHelp.style.marginTop=8;
        }
        static Label Text(VisualElement parent,string value,int size,Color color){var label=new Label(value);label.style.fontSize=size;label.style.color=color;parent.Add(label);return label;}
        static Button Button(VisualElement parent,string value,Action action)
        {
            var b=new Button(action){text=value};b.AddToClassList("eternal-button");b.style.height=44;b.style.marginTop=10;b.style.backgroundColor=new Color(.14f,.21f,.20f);b.style.color=Paper;b.style.borderTopWidth=b.style.borderBottomWidth=b.style.borderLeftWidth=b.style.borderRightWidth=1;b.style.borderTopColor=b.style.borderBottomColor=b.style.borderLeftColor=b.style.borderRightColor=Bronze;parent.Add(b);return b;
        }
        Sprite Portrait(string id)
        {
            var f=OriginalCatalog.Atlas(id).attack.frames[0];var texture=OriginalCatalog.Texture(id);
            var sprite=Sprite.Create(texture,new Rect(f.region[0],1024-f.region[1]-f.region[3],f.region[2],f.region[3]),new Vector2(.5f,.5f));portraits.Add(sprite);return sprite;
        }
        void Begin(string faction)
        {
            var store=new NativeSessionStore(NativeSessionStore.LatestPath(ProfileDirectory,faction),faction);var saved=store.Read();JObject payload;
            if(saved.Ok)payload=saved.Payload;
            else if(saved.Status=="missing")
            {payload=NativePlayerSession.NewPayload(catalog,faction);if(!store.Write(payload)){message.text="기록을 저장하지 못했습니다. 저장 위치와 권한을 확인해 주세요.";return;}}
            else{message.text="기록을 읽지 못했습니다. 기존 파일은 보존되어 있습니다.";return;}
            var session=new NativePlayerSession(catalog,payload,store);
            if(session.State.Faction!=faction){var switched=session.State.SwitchAccountFaction(faction);if(!switched.Ok||switched.SavePending){message.text=switched.Message;return;}}
            StartSession(session);
        }
        void ImportLegacy()
        {
            string source=(legacyPath.value??"").Trim();if(source.Length==0){message.text="가져올 저장 파일 경로를 입력해 주세요.";return;}
            LegacySaveResult old;
            try{old=LegacySaveCodec.Read(Path.GetFullPath(source));}catch(Exception e)when(e is ArgumentException||e is NotSupportedException){message.text="파일 경로를 확인해 주세요.";return;}
            if(!old.Ok){message.text=old.Unsupported?"더 최신 버전의 기록입니다. 원본은 보존했습니다.":"유효한 기록을 읽지 못했습니다. 원본은 보존했습니다.";return;}
            string faction=(string)old.Data["selected_faction"];if(faction!="aurelia"&&faction!="noxfera"){message.text="기록의 진영을 확인해 주세요.";return;}
            var payload=NativePlayerSession.ImportPayload(catalog,old.Data);
            string path=Path.Combine(ProfileDirectory,faction+"-import-"+Guid.NewGuid().ToString("N")+".json");var store=new NativeSessionStore(path,faction);
            if(!store.Write(payload)){message.text="Unity 기록을 저장하지 못했습니다. 원본은 보존했습니다.";return;}
            StartSession(new NativePlayerSession(catalog,payload,store));
        }
        void StartSession(NativePlayerSession session)
        {
            session.State.CalculateOffline();
            var game=new GameObject("Eternal native player session").AddComponent<HuntingMigrationReview>();game.BindPlayerSession(session);Destroy(gameObject);
        }
        void OnDestroy(){foreach(var sprite in portraits)if(sprite!=null)Destroy(sprite);if(panel!=null)Destroy(panel);}
    }
}
