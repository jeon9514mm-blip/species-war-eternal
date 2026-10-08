Shader "Eternal/PaintedArena"
{
    Properties { _MainTex("Original arena painting",2D)="white" {} _Tint("Paint exposure",Color)=(1,1,1,1) }
    SubShader
    {
        Tags { "RenderPipeline"="UniversalPipeline" "Queue"="Geometry" "RenderType"="Opaque" }
        Pass
        {
            Tags { "LightMode"="UniversalForwardOnly" }
            Cull Off ZWrite On
            HLSLPROGRAM
            #pragma vertex Vert
            #pragma fragment Frag
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN
            #pragma multi_compile_fragment _ _SHADOWS_SOFT
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            TEXTURE2D(_MainTex);SAMPLER(sampler_MainTex);
            CBUFFER_START(UnityPerMaterial)
            float4 _Tint;float4 _MainTex_TexelSize;
            CBUFFER_END
            struct A {float4 positionOS:POSITION;};
            struct V {float4 positionCS:SV_POSITION;float4 screen:TEXCOORD0;float3 world:TEXCOORD1;};
            V Vert(A v){V o;o.world=TransformObjectToWorld(v.positionOS.xyz);o.positionCS=TransformWorldToHClip(o.world);o.screen=ComputeScreenPos(o.positionCS);return o;}
            half4 Frag(V v):SV_Target
            {
                // Preserve the painted perspective. Live footprints and actors
                // retain their own floor coordinates and depth above this plane.
                float2 uv=v.screen.xy/v.screen.w;
                float viewAspect=unity_OrthoParams.x/unity_OrthoParams.y;
                float artAspect=_MainTex_TexelSize.z/_MainTex_TexelSize.w;
                if(viewAspect>artAspect)uv.y=(uv.y-.5)*(artAspect/viewAspect)+.5;
                else uv.x=(uv.x-.5)*(viewAspect/artAspect)+.5;
                half3 paint=SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex,uv).rgb*_Tint.rgb;
                Light sun=GetMainLight(TransformWorldToShadowCoord(v.world));
                return half4(paint*(.92+.08*sun.shadowAttenuation),1);
            }
            ENDHLSL
        }
    }
}
