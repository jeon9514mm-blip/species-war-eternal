namespace Eternal.UnityMigration
{
    public sealed partial class GameStateCommands
    {
        // New Unity preview loop, deliberately not a reproduction of every
        // Godot settlement service. This route rejects actual player payloads.
        public StateCommandResult SettleReviewHuntPack(int pack,long gold,int xp)=>Commit(state=>
        {
            if((bool?)state["native_review_fixture"]!=true)return StateCommandResult.Fail("임시 플레이테스트에서만 사용할 수 있습니다.");
            long previous=Integer(state["native_review_settled_pack"],0,0,int.MaxValue);
            if(pack!=previous+1||gold<0||gold>CurrencyCap||xp<0||xp>100000000||gold==0&&xp==0)return StateCommandResult.Fail("중복되거나 잘못된 사냥 보상입니다.");
            state["native_review_settled_pack"]=pack;
            AddCurrency(state,"wallet_gold",gold);AddCurrency(state,"wallet_xp",xp);
            int distributed=DistributeXp(state,xp);
            return StateCommandResult.Success("무리 격파 · 골드 +"+gold+" · 영웅 경험치 +"+distributed,gold,distributed);
        });
    }
}
