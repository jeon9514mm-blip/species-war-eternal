using UnityEngine;
using UnityEngine.UIElements;

namespace Eternal.UnityMigration
{
    public sealed partial class HuntingMigrationReview
    {
        void ShowRaidSelection()
        {
            PanelHeader("지역 레이드");
            Text(modal,"원정대 10인 · 3단계 보스 · 제한 시간 4분",12).style.color=Moss;
            var scope=Text(modal,PersistentPlayer?"현재 원정대 "+ReviewState.DeployedHeroes().Count+"인 · 평균 Lv"+PlayerLevel()+"로 도전합니다. 입장 후 보상 없는 패턴 훈련을 선택할 수 있습니다.":"Lv100 임시 원정대로 도전합니다. 패턴 훈련은 입장 후 선택할 수 있습니다.",12);scope.style.whiteSpace=WhiteSpace.Normal;scope.style.marginTop=8;
            var list=new ScrollView();list.style.flexGrow=1;list.style.marginTop=8;modal.Add(list);
            foreach(string zone in new[]{"gray_meadow","forgotten_mine","moonrest_forest"})
            {
                string id=zone;bool meadow=zone=="gray_meadow",mine=zone=="forgotten_mine";
                var data=HuntingSimulation.Canonical;var z=data["zones"][id];var design=data["catalogs"]["raid"]["data"]["RAIDS"][id];
                var card=Box(list,"raid-card-"+zone,new Color(.075f,.10f,.11f));card.style.marginTop=8;card.style.marginBottom=8;card.style.paddingLeft=10;card.style.paddingRight=10;card.style.paddingTop=10;card.style.paddingBottom=10;
                var row=Row(card);row.style.alignItems=Align.Center;
                var scene=new VisualElement();scene.style.width=95;scene.style.height=97;scene.style.flexShrink=0;scene.style.marginRight=12;scene.style.backgroundColor=new Color(.035f,.05f,.06f);row.Add(scene);
                string map=meadow?"sky-court":mine?"amber-quarry":"lunar-sanctum";
                var painting=new Image{image=Resources.Load<Texture2D>("Eternal/Environment/"+map),scaleMode=ScaleMode.ScaleAndCrop};painting.style.width=95;painting.style.height=97;scene.Add(painting);
                var boss=new Image{sprite=InspectionPortrait(meadow?"grun":mine?"morgul":"selene_boss"),scaleMode=ScaleMode.ScaleToFit};boss.style.position=Position.Absolute;boss.style.left=14;boss.style.top=11;boss.style.width=67;boss.style.height=80;scene.Add(boss);
                var copy=new VisualElement();copy.style.flexGrow=1;copy.style.minWidth=0;row.Add(copy);
                var enter=Button(copy,(string)z["boss"],()=>StartRaid(id));enter.style.marginLeft=0;enter.style.marginRight=0;enter.style.minWidth=0;enter.style.fontSize=15;
                var identity=Text(copy,meadow?"갑주 파괴 · 정면 카운터":mine?"수정핵 제거 · 낙석 회피":"월식 의식 저지 · 표식 회피",11);identity.style.color=Bronze;identity.style.whiteSpace=WhiteSpace.Normal;identity.style.marginTop=8;
                Text(copy,meadow?"하늘의 유적":mine?"잊힌 호박빛 채석장":"달빛 성소",11).style.color=Moss;
                var description=Text(card,(string)design["description"],12);description.style.whiteSpace=WhiteSpace.Normal;description.style.marginTop=10;
                if(PersistentPlayer)Text(card,"승리 보상 · 골드 "+((long)z["gold"]*20).ToString("N0")+" · 경험치 "+((int)z["xp"]*10).ToString("N0"),12).style.color=Bronze;
            }
        }
    }
}
