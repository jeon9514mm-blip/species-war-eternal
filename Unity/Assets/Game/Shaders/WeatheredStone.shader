Shader "Eternal/WeatheredStone"
{
    Properties
    {
        _BaseMap("1024 stone grain",2D)="white" {}
        _MicroNormal("1024 micro normal",2D)="bump" {}
        _Roughness("Roughness",Range(0,1))=.58
        _Metallic("Metallic",Range(0,1))=.32
        _Moss("Moss crack coverage",Range(0,1))=.18
        _Patina("Patina edge coverage",Range(0,1))=.25
        _Wear("Edge wear",Range(0,1))=.8
        _MossGlow("Moss emission",Range(0,1))=.25
        _Tint("Regional stone tint",Color)=(1,1,1,1)
    }
    SubShader
    {
        Tags {"RenderPipeline"="UniversalPipeline" "RenderType"="Opaque" "Queue"="Geometry"}
        Pass
        {
            Tags {"LightMode"="UniversalForward"}
            HLSLPROGRAM
            #pragma vertex Vert
            #pragma fragment Frag
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN
            #pragma multi_compile_fragment _ _SHADOWS_SOFT
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            TEXTURE2D(_BaseMap);SAMPLER(sampler_BaseMap);
            TEXTURE2D(_MicroNormal);SAMPLER(sampler_MicroNormal);
            CBUFFER_START(UnityPerMaterial)
            float _Roughness,_Metallic,_Moss,_Patina,_Wear,_MossGlow;
            float4 _Tint;
            CBUFFER_END
            struct A {float4 p:POSITION;};
            struct V {float4 p:SV_POSITION;float3 world:TEXCOORD0;};
            V Vert(A i){V o;o.world=TransformObjectToWorld(i.p.xyz);o.p=TransformWorldToHClip(o.world);return o;}
            float Hash(float2 p){return frac(sin(dot(p,float2(127.1,311.7)))*43758.5453);}
            float Noise(float2 p){float2 i=floor(p),f=frac(p);f=f*f*(3-2*f);return lerp(lerp(Hash(i),Hash(i+float2(1,0)),f.x),lerp(Hash(i+float2(0,1)),Hash(i+1),f.x),f.y);}
            half4 Frag(V i):SV_Target
            {
                float2 uv=i.world.xz;
                float row=floor(uv.y/1.65);
                float2 grid=float2(uv.x/3.05+frac(row*.5),uv.y/1.65);
                float2 f=frac(grid),edge=min(f,1-f);
                float seam=min(edge.x*3.05,edge.y*1.65)+(Noise(uv*23)-.5)*.014;
                float crack=1-smoothstep(.022,.058,seam);
                float wear=(1-smoothstep(.04,.16,seam))*(1-crack);
                float grain=Noise(uv*7)*.55+Noise(uv*37)*.3+Noise(uv*110)*.15;
                float stoneVariation=Hash(floor(grid));
                float3 base=lerp(float3(.17,.175,.14),float3(.31,.285,.215),stoneVariation)*(.62+grain*.62);
                // Sample the existing 1024 source only at grain scale. The large
                // authored slab layout stays rectangular, with no giant cracks.
                float2 detailUV=frac(uv*.35+stoneVariation*.13);
                float3 source=SAMPLE_TEXTURE2D(_BaseMap,sampler_BaseMap,detailUV).rgb;
                base*=.72+dot(source,float3(.3,.59,.11))*.72;
                base*=1-Noise(uv*.72)*.18;
                base+=wear*_Wear*.13;
                base*=1-crack*.70;
                float growth=Noise(uv*1.8)+Noise(uv*9)*.22;
                float moss=crack*smoothstep(1-_Moss*1.8,1.06,growth);
                float patina=wear*smoothstep(1-_Patina,1,Noise(uv*3.5));
                base=lerp(base,float3(.27,.36,.225),moss*.88);
                base=lerp(base,float3(.14,.245,.185),patina*.7);
                base*=_Tint.rgb;
                float2 signEdge=sign(.5-f);
                float2 bevel=float2(edge.x*3.05<.13?signEdge.x*.15:0,edge.y*1.65<.13?signEdge.y*.15:0);
                float3 micro=UnpackNormal(SAMPLE_TEXTURE2D(_MicroNormal,sampler_MicroNormal,detailUV));
                float2 pitting=float2(Noise((uv+float2(.025,0))*7)-Noise((uv-float2(.025,0))*7),Noise((uv+float2(0,.025))*7)-Noise((uv-float2(0,.025))*7));
                float3 normal=normalize(float3(bevel.x+micro.x*.35+pitting.x*.25,1,bevel.y+micro.y*.35+pitting.y*.25));
                float wet=smoothstep(.80,.93,Noise(uv*.30))*(1-crack);
                half alpha=1;BRDFData data;
                InitializeBRDFData(base,_Metallic,float3(.04,.04,.04),lerp(1-_Roughness,.72,wet*.35),alpha,data);
                Light sun=GetMainLight(TransformWorldToShadowCoord(i.world));
                half3 color=LightingPhysicallyBased(data,sun,normal,GetWorldSpaceNormalizeViewDir(i.world));
                color+=SampleSH(normal)*data.diffuse*(1-crack*.7)*.70;
                color+=moss*float3(.20,.30,.16)*_MossGlow;
                return half4(color,1);
            }
            ENDHLSL
        }
    }
}
