using System;
using UnityEngine.UIElements;

namespace Eternal.UnityMigration
{
    public sealed partial class HuntingMigrationReview
    {
        readonly System.Random reviewSummonRandom=new(18473);
        void ShowSummons()
        {
            PanelHeader("소환 · 수호신");var scroll=new ScrollView();scroll.style.flexGrow=1;modal.Add(scroll);
            Text(scroll,"보유 젬 "+ReviewState.WalletGems.ToString("N0"),18).style.marginTop=14;GrowthNotice(scroll);
            Text(scroll,"영웅 소환",18).style.marginTop=16;
            Text(scroll,"현재 진영의 15명 중 영웅 조각 12개. 10번째에는 30개를 획득합니다.",13).style.whiteSpace=WhiteSpace.Normal;
            var state=ReviewState.Snapshot();int pity=(int)GameStateCommands.Integer(state["summon_pity"],0,0,9);
            Text(scroll,"조각 확정까지 "+(10-pity)+"회",13).style.color=Moss;
            GrowthButton(scroll,"영웅 조각 소환 · 젬 100",()=>ReviewState.SummonHero(reviewSummonRandom),ShowSummons,ReviewState.WalletGems>=100).style.marginTop=8;
            Text(scroll,"수호신 소환",18).style.marginTop=22;
            Text(scroll,"고급 55% · 희귀 27% · 에픽 12% · 전설 5% · 신화 1%",13).style.whiteSpace=WhiteSpace.Normal;
            Text(scroll,"전설 이상 "+(30-ReviewState.GuardianLegendaryPity)+"회 · 신화 "+(80-ReviewState.GuardianMythicPity)+"회 이내 확정",13).style.color=Bronze;
            bool free=ReviewState.GuardianFreeAvailable;
            GrowthButton(scroll,free?"첫 무료 수호신 소환":"수호신 소환 · 젬 80",()=>ReviewState.SummonGuardian(reviewSummonRandom),ShowSummons,free||ReviewState.WalletGems>=80).style.marginTop=8;
            Button(scroll,"보유 수호신",ShowGuardians).style.marginLeft=0;
            Text(scroll,PersistentPlayer?"소환 결과는 현재 진영의 Unity 기록에 자동 저장됩니다.":"독립 검수 상태의 소환입니다. 재실행하면 초기화됩니다.",12).style.marginTop=22;Text(scroll,"수호신 장착 보너스는 사냥 영웅 능력치에 적용됩니다. 수호신의 별도 공격 연출은 이관 중입니다.",12).style.whiteSpace=WhiteSpace.Normal;
        }
        void ShowGuardians()
        {
            PanelHeader("보유 수호신");var scroll=new ScrollView();scroll.style.flexGrow=1;modal.Add(scroll);GrowthNotice(scroll);
            var progress=ReviewState.PetProgress();Text(scroll,"수호신 Lv."+progress.level+" · "+new[]{"유년","각성","초월"}[progress.evolution]+" · XP "+progress.xp,16).style.marginTop=14;
            foreach(string id in ReviewState.OwnedGuardians())
            {
                string selected=id;var profile=ReviewState.GuardianProfile(id);int copies=ReviewState.GuardianCopies(id),resonance=Math.Min(3,1+Math.Max(0,copies-1)/3);
                var card=new VisualElement();card.AddToClassList("growth-gear-card");scroll.Add(card);
                Text(card,(string)profile["name"],16).style.color=Bronze;Text(card,profile["tier"]+" · "+copies+"개 · 공명 "+resonance,13).style.color=Moss;
                Text(card,(string)profile["description"],13).style.whiteSpace=WhiteSpace.Normal;
                GrowthButton(card,ReviewState.EquippedGuardian==id?"장착 중":"수호신 장착",()=>ReviewState.EquipGuardian(selected),ShowGuardians,ReviewState.EquippedGuardian!=id).style.marginTop=8;
            }
            Button(scroll,"소환으로",ShowSummons).style.marginLeft=0;
        }
    }
}
