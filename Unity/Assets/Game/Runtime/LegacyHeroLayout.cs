using Newtonsoft.Json.Linq;

namespace Eternal.UnityMigration
{
    public static class LegacyHeroLayout
    {
        public static string Row(int slot)=>slot<3?"front":slot<7?"middle":"rear";
        public static int Range(JObject hero,int slot)
        {
            string row=Row(slot),role=(string)hero["role_group"]??"딜러";
            if((string)hero["reach"]=="melee")return row=="front"?1:2;
            return role=="서포터"||role=="컨트롤러"||row=="rear"?3:2;
        }
    }
}
