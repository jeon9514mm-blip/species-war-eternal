Shader "Eternal/RaidTelegraph"
{
    Properties
    {
        _Tint("Warning colour",Color)=(1,.24,.28,1)
        _Progress("Authoritative cast progress",Range(0,1))=0
        _ArenaBounds("Playable arena",Vector)=(-12.2,-4.12,12.2,4.12)
    }
    SubShader
    {
        Tags { "RenderPipeline"="UniversalPipeline" "Queue"="Transparent-10" "RenderType"="Transparent" }
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
            half4 _Tint;
            float _Progress;
            float4 _ArenaBounds;
            CBUFFER_END
            struct A {float4 p:POSITION;};
            struct V {float4 p:SV_POSITION;float2 ground:TEXCOORD0;};
            V Vert(A i){V o;float3 world=TransformObjectToWorld(i.p.xyz);o.p=TransformWorldToHClip(world);o.ground=world.xz;return o;}
            half4 Frag(V i):SV_Target
            {
                clip(min(min(i.ground.x-_ArenaBounds.x,_ArenaBounds.z-i.ground.x),min(i.ground.y-_ArenaBounds.y,_ArenaBounds.w-i.ground.y)));
                float stripe=frac((i.ground.x+i.ground.y)*1.3-_Time.y*.16);
                float edge=fwidth(stripe)*1.5;
                float hatch=smoothstep(.68-edge,.68+edge,stripe)*(1-smoothstep(.88-edge,.88+edge,stripe));
                float urgency=saturate(_Progress);
                // Only the existing frozen damage mesh is shaded. Hatching
                // and urgency never resize a warning or introduce safe areas.
                float opacity=.10+urgency*.14+hatch*(.07+urgency*.12);
                return half4(_Tint.rgb*(.78+hatch*.22),opacity*_Tint.a);
            }
            ENDHLSL
        }
    }
}
