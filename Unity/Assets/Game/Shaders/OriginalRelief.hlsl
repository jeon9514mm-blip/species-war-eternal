#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
TEXTURE2D(_MainTex);SAMPLER(sampler_MainTex);
CBUFFER_START(UnityPerMaterial)
float4 _Tint,_AtlasRect,_PaintSize,_Anchor,_HairRect;
float4 _Cape0,_Cape1,_Cape2,_Cape3,_Cape4;
float _HairCards,_VisualTime,_Wind,_Outline,_CapeEnabled,_Breath;
CBUFFER_END
struct A {float4 p:POSITION;float3 n:NORMAL;float2 uv:TEXCOORD0;};
struct V {float4 p:SV_POSITION;float3 world:TEXCOORD0;float3 normal:TEXCOORD1;float2 uv:TEXCOORD2;float2 local:TEXCOORD3;float2 card:TEXCOORD4;};
float2 AtlasUV(float2 local){return float2(_AtlasRect.x+local.x*_AtlasRect.z,_AtlasRect.y-local.y*_AtlasRect.w);}
float2 ClampUV(float2 uv){return clamp(uv,float2(_AtlasRect.x+.5/1024,_AtlasRect.y-_AtlasRect.w+.5/1024),float2(_AtlasRect.x+_AtlasRect.z-.5/1024,_AtlasRect.y-.5/1024));}
float3 Pose(A input,out float2 local)
{
    local=_HairCards>.5?_HairRect.xy+input.uv*_HairRect.zw:input.uv;
    float3 p=float3(local.x*_PaintSize.x-_Anchor.x,_Anchor.y-local.y*_PaintSize.y,input.p.z*_PaintSize.y*.06);
    if(_HairCards>.5)
    {
        p.z=-.005;
        float cluster=floor(input.uv.x*12)/12;
        float phase=lerp(input.uv.x,cluster,.3)*11;
        float sway=sin(_VisualTime*2.3+phase+input.uv.y*4)*_Wind*2.5;
        float loose=sin(_VisualTime*4.2+input.uv.x*91+input.uv.y*37)*.1*.45;
        p.x+=(sway+loose)*smoothstep(.12,.8,input.uv.y)*_PaintSize.z;
    }
    else if(_CapeEnabled>.5)
    {
        float4 ink=SAMPLE_TEXTURE2D_LOD(_MainTex,sampler_MainTex,ClampUV(AtlasUV(local)),0);
        float warm=step(ink.g*1.08,ink.r)*step(ink.b*1.3,ink.g);
        float cape=smoothstep(.2,.36,abs(local.x-.5))*smoothstep(.28,.4,local.y)*(1-smoothstep(.86,.98,local.y))*(1-warm)*ink.a;
        float segment=saturate((local.y-.3)/.6)*4;
        float2 drift=segment<1?lerp(_Cape0.xy,_Cape1.xy,segment):segment<2?lerp(_Cape1.xy,_Cape2.xy,segment-1):segment<3?lerp(_Cape2.xy,_Cape3.xy,segment-2):lerp(_Cape3.xy,_Cape4.xy,segment-3);
        p.xy+=drift*cape;
    }
    p.y+=_Breath*smoothstep(0,_PaintSize.y*.55,max(0,p.y));
    return p;
}
V ReliefVert(A input)
{
    V o;float2 local;float3 p=Pose(input,local);o.world=TransformObjectToWorld(p);o.p=TransformWorldToHClip(o.world);o.normal=TransformObjectToWorldNormal(_HairCards>.5?float3(0,0,-1):input.n);o.uv=AtlasUV(local);o.local=local;o.card=input.uv;return o;
}
float HairMask(float2 card)
{return max(1-smoothstep(.38,.72,card.y),smoothstep(.17,.37,abs(card.x-.5)));}
half4 ReliefFrag(V i):SV_Target
{
    float4 ink=SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex,ClampUV(i.uv));
    float edge=0;
    if(_HairCards>.5)ink.a*=HairMask(i.card);
    else if(_Outline>0)
    {
        float2 d=float2(_Outline,_Outline)/1024;
        edge=max(max(SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex,ClampUV(i.uv+float2(d.x,0))).a,SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex,ClampUV(i.uv-float2(d.x,0))).a),max(SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex,ClampUV(i.uv+float2(0,d.y))).a,SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex,ClampUV(i.uv-float2(0,d.y))).a));
        edge*=.6*(1-smoothstep(.08,.35,ink.a));
    }
    clip(max(ink.a,edge)*_Tint.a-(_HairCards>.5?.2:.12));
    half3 base=lerp(ink.rgb*_Tint.rgb,0,edge);
    half warm=smoothstep(.05,.2,ink.r-ink.b)*smoothstep(.4,.7,ink.g);
    half armor=warm*smoothstep(.25,.38,i.local.y)*(1-smoothstep(.8,.96,i.local.y));
    half metallic=_HairCards>.5?0:armor*.32;
    half3 normal=normalize(i.normal),view=GetWorldSpaceNormalizeViewDir(i.world);if(dot(normal,view)<0)normal=-normal;
    half alpha=1;BRDFData data;InitializeBRDFData(base,metallic,half3(.04,.04,.04),_HairCards>.5?.26:lerp(.18,.42,armor),alpha,data);
    Light light=GetMainLight(TransformWorldToShadowCoord(i.world));
    // The original painting already contains art lighting. Preserve that base
    // while adding relief illumination; do not let ambient shadow turn it black.
    half3 color=base*.60+LightingPhysicallyBased(data,light,normal,view)*.40+SampleSH(normal)*data.diffuse*.20;
    half rim=pow(1-saturate(dot(normal,view)),3)*.25;color+=base*rim+base*warm*.0375;
    if(_HairCards>.5)
    {
        // Directional hair highlight approximation; this is not native URP SSS.
        half3 tangent=normalize(TransformObjectToWorldDir(float3(0,1,0)));
        half band=pow(saturate(1-abs(dot(normalize(light.direction+view),tangent))),12);
        color+=base*band*.10*light.shadowAttenuation;
    }
    return half4(color,1);
}
