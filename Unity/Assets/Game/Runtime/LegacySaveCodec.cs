using System;
using System.Collections.Generic;
using System.Globalization;
using System.IO;
using System.Linq;
using System.Numerics;
using System.Security.Cryptography;
using System.Text;
using Newtonsoft.Json;
using Newtonsoft.Json.Linq;

namespace Eternal.UnityMigration
{
    public sealed class LegacySaveResult
    {
        public bool Ok,Unsupported,Migrated;
        public string Status,Raw,Source;
        public JObject Data;
    }
    // Read-only compatibility with production SaveStore v37. No write method,
    // automatic user-path discovery, wallet credit or schema mutation belongs here.
    public static class LegacySaveCodec
    {
        public const int Version=37,IntegrityRequiredVersion=27,MaxBytes=8*1024*1024;
        const string Integrity="_save_integrity";
        public static LegacySaveResult Read(string path)
        {
            bool exists=false;
            foreach(string suffix in new[]{"",".bak",".tmp"})
            {
                exists|=File.Exists(path+suffix);var result=ReadCandidate(path+suffix);
                if(result.Unsupported)return result;
                if(result.Ok){result.Source=suffix==""?"primary":suffix==".bak"?"backup":"temporary";return result;}
            }
            return Fail(exists?"corrupt":"missing");
        }
        public static LegacySaveResult ReadCandidate(string path)
        {
            if(!File.Exists(path))return Fail("missing");
            try
            {
                using var stream=new FileStream(path,FileMode.Open,FileAccess.Read,FileShare.Read);
                if(stream.Length>MaxBytes)return Fail("too_large");
                using var reader=new StreamReader(stream,new UTF8Encoding(false,true),true);
                return Parse(reader.ReadToEnd());
            }
            catch(IOException){return Fail("read_failed");}
            catch(UnauthorizedAccessException){return Fail("read_failed");}
            catch(DecoderFallbackException){return Fail("invalid_json");}
        }
        public static LegacySaveResult Parse(string raw)
        {
            if(raw==null)return Fail("missing");
            if(Encoding.UTF8.GetByteCount(raw)>MaxBytes)return Fail("too_large");
            JObject payload;
            try
            {
                using var text=new StringReader(raw);
                using var reader=new JsonTextReader(text){DateParseHandling=DateParseHandling.None,FloatParseHandling=FloatParseHandling.Double,MaxDepth=128};
                var token=JToken.ReadFrom(reader);
                if(token is not JObject value||value.Count==0)return Fail("invalid_json");
                payload=value;
                while(reader.Read())if(reader.TokenType!=JsonToken.Comment)return Fail("invalid_json");
            }
            catch(JsonException){return Fail("invalid_json");}
            catch(FormatException){return Fail("invalid_json");}
            if(!Number(payload["save_version"]??new JValue(1),out double version)||!double.IsFinite(version)||version<1||version%1!=0)return Fail("invalid_version");
            if(version>Version)return new LegacySaveResult{Status="unsupported_version",Unsupported=true};
            if(payload.TryGetValue(Integrity,out var integrityToken))
            {
                if(integrityToken is not JObject integrity||!Number(integrity["format"],out double format)||format!=1||integrity["sha256"]?.Type!=JTokenType.String)return Fail("invalid_integrity");
                payload.Remove(Integrity);
                if(Hash(Canonical(payload))!=(string)integrity["sha256"])return Fail("checksum_mismatch");
            }
            else if(version>=IntegrityRequiredVersion)return Fail("missing_integrity");
            return new LegacySaveResult{Ok=true,Status="loaded",Raw=raw,Data=payload,Migrated=version<Version};
        }
        static LegacySaveResult Fail(string status)=>new(){Status=status};
        static bool Number(JToken token,out double number)
        {
            number=0;if(token==null||token.Type!=JTokenType.Integer&&token.Type!=JTokenType.Float)return false;
            try{var value=((JValue)token).Value;number=value is BigInteger big?(double)big:Convert.ToDouble(value,CultureInfo.InvariantCulture);return true;}catch(Exception e)when(e is InvalidCastException||e is OverflowException||e is FormatException){return false;}
        }
        public static string Hash(string text)
        {using var sha=SHA256.Create();return BitConverter.ToString(sha.ComputeHash(Encoding.UTF8.GetBytes(text))).Replace("-","").ToLowerInvariant();}
        public static string Canonical(JToken value)
        {var text=new StringBuilder();Write(value,text);return text.ToString();}
        static readonly IComparer<string> CodePointOrder=Comparer<string>.Create((left,right)=>
        {
            int a=0,b=0;
            int Next(string s,ref int i){int code=s[i++];if(char.IsHighSurrogate((char)code)&&i<s.Length&&char.IsLowSurrogate(s[i]))code=char.ConvertToUtf32((char)code,s[i++]);return code;}
            while(a<left.Length&&b<right.Length){int comparison=Next(left,ref a).CompareTo(Next(right,ref b));if(comparison!=0)return comparison;}
            return (left.Length-a).CompareTo(right.Length-b);
        });
        static void Write(JToken value,StringBuilder text)
        {
            if(value==null||value.Type==JTokenType.Null){text.Append("null");return;}
            if(value is JObject obj)
            {
                text.Append('{');bool first=true;
                foreach(var property in obj.Properties().OrderBy(p=>p.Name,CodePointOrder))
                {if(!first)text.Append(',');first=false;Quote(property.Name,text);text.Append(':');Write(property.Value,text);}
                text.Append('}');return;
            }
            if(value is JArray array)
            {text.Append('[');for(int i=0;i<array.Count;i++){if(i>0)text.Append(',');Write(array[i],text);}text.Append(']');return;}
            if(value.Type==JTokenType.Boolean){text.Append(value.Value<bool>()?"true":"false");return;}
            if(value.Type==JTokenType.String){Quote(value.Value<string>(),text);return;}
            if(Number(value,out double number)){text.Append(FormatNumber(number));return;}
            throw new InvalidDataException("Unsupported legacy JSON value: "+value.Type);
        }
        static void Quote(string value,StringBuilder text)
        {
            text.Append('"');
            foreach(char c in value)
            {
                switch(c)
                {
                    case '\\':text.Append("\\\\");break;case '"':text.Append("\\\"");break;
                    case '\b':text.Append("\\b");break;case '\f':text.Append("\\f");break;
                    case '\n':text.Append("\\n");break;case '\r':text.Append("\\r");break;
                    case '\t':text.Append("\\t");break;case '\v':text.Append("\\v");break;
                    default:text.Append(c);break;
                }
            }
            text.Append('"');
        }
        public static string FormatNumber(double value)
        {
            // Godot 4.7.2 JSON.cpp: default precision is 14-floor(log10(abs)),
            // at least one decimal, capped at 32 by String::num. All parsed JSON
            // numbers are doubles, including originally integer-valued fields.
            // Fixed-point output below rounds the exact IEEE754 value, avoiding
            // culture and Mono's decimal formatting differences.
            // Source: https://github.com/godotengine/godot/tree/4.7.2-stable/core
            if(double.IsNaN(value))return "null";
            if(double.IsPositiveInfinity(value))return "1e99999";
            if(double.IsNegativeInfinity(value))return "-1e99999";
            if(value==0)return "0.0";
            int precision=Math.Clamp(14-(int)Math.Floor(Math.Log10(Math.Abs(value))),1,32);
            ulong bits=unchecked((ulong)BitConverter.DoubleToInt64Bits(value));
            bool negative=(bits>>63)!=0;int exponent=(int)((bits>>52)&2047);
            ulong mantissa=bits&0xfffffffffffffUL;
            if(exponent!=0)mantissa|=1UL<<52;
            int shift=exponent==0?-1074:exponent-1023-52;
            BigInteger numerator=mantissa,denominator=BigInteger.One;
            if(shift>=0)numerator<<=shift;else denominator<<=-shift;
            numerator*=BigInteger.Pow(10,precision);
            var rounded=BigInteger.DivRem(numerator,denominator,out var remainder);
            var twice=remainder<<1;
            if(twice>denominator||twice==denominator&&!rounded.IsEven)rounded++;
            string digits=rounded.ToString(CultureInfo.InvariantCulture).PadLeft(precision+1,'0');
            string formatted=digits.Insert(digits.Length-precision,".").TrimEnd('0');
            if(formatted.EndsWith(".",StringComparison.Ordinal))formatted+="0";
            return negative?"-"+formatted:formatted;
        }
    }
}
