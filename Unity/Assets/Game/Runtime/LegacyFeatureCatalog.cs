using System;
using System.Globalization;
using Newtonsoft.Json.Linq;

namespace Eternal.UnityMigration
{
    // Exported by the original Godot scripts without loading a player save.
    public static class LegacyFeatureCatalog
    {
        static readonly Lazy<JObject> cache=new(()=>JObject.Parse(OriginalCatalog.Required("legacy-features").text));
        public static JObject Data=>cache.Value;
        public static JObject Object(JToken value)=>value as JObject??new JObject();
        public static JArray Array(JToken value)=>value as JArray??new JArray();
        public static long N(JToken value,long fallback=0,long cap=1000000000)=>GameStateCommands.Integer(value,fallback,0,cap);
        public static double F(JToken value,double fallback=0)
        {if(value?.Type!=JTokenType.Integer&&value?.Type!=JTokenType.Float)return fallback;double n=(double)value;return double.IsFinite(n)?n:fallback;}
        public static bool Flag(JToken value)=>value?.Type==JTokenType.Boolean&&(bool)value;
        public static long Now=>DateTimeOffset.UtcNow.ToUnixTimeSeconds();
        public static string Day(long now)=>DateTimeOffset.FromUnixTimeSeconds(now+9*3600).ToString("yyyy-MM-dd",CultureInfo.InvariantCulture);
        public static string Week(long now)=>((now+9*3600-4*86400)/604800).ToString(CultureInfo.InvariantCulture);
        public static string ValidDay(JToken value)=>value?.Type==JTokenType.String&&DateTime.TryParseExact((string)value,"yyyy-MM-dd",CultureInfo.InvariantCulture,DateTimeStyles.None,out var date)&&date.Year>=1970&&date.Year<=2100?(string)value:"";
        public static string ValidWeek(JToken value)=>value?.Type==JTokenType.String&&long.TryParse((string)value,out long n)&&n>=0&&n<=10000?n.ToString(CultureInfo.InvariantCulture):"";
    }
}
