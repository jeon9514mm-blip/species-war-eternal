Shader "Eternal/EffectParticles"
{
    Properties { _Tint("Tint",Color)=(1,1,1,1) _SoftDot("Soft dot",Float)=1 _SoftLine("Soft line glow",Float)=0 _ClipArena("Clip to raid floor",Float)=0 _ArenaBounds("Raid x/z bounds",Vector)=(-12.2,-4.12,12.2,4.12) }
    SubShader
    {
        Tags { "RenderPipeline"="UniversalPipeline" "Queue"="Transparent+10" "RenderType"="Transparent" }
        Pass
        {
            Tags { "LightMode"="SRPDefaultUnlit" }
            Blend SrcAlpha OneMinusSrcAlpha
            ZWrite Off
            Cull Off
            HLSLPROGRAM
            #pragma vertex Vert
            #pragma fragment Frag
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            CBUFFER_START(UnityPerMaterial)
            float4 _Tint,_ArenaBounds;
            float _SoftDot,_SoftLine,_ClipArena;
            CBUFFER_END
            struct A {float4 p:POSITION;float2 uv:TEXCOORD0;float4 c:COLOR;};
            struct V {float4 p:SV_POSITION;float2 uv:TEXCOORD0;float4 c:COLOR;float3 world:TEXCOORD1;};
            V Vert(A i){V o;o.world=TransformObjectToWorld(i.p.xyz);o.p=TransformWorldToHClip(o.world);o.uv=i.uv;o.c=i.c*_Tint;return o;}
            half4 Frag(V i):SV_Target
            {
                if(_ClipArena>.5)clip(min(min(i.world.x-_ArenaBounds.x,_ArenaBounds.z-i.world.x),min(i.world.z-_ArenaBounds.y,_ArenaBounds.w-i.world.z)));
                float radial=saturate(1-length(i.uv*2-1));i.c.a*=lerp(1,smoothstep(0,.4,radial),_SoftDot)*lerp(1,pow(saturate(1-abs(i.uv.y*2-1)),2),_SoftLine);return i.c;
            }
            ENDHLSL
        }
    }
}
