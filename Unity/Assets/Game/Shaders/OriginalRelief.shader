Shader "Eternal/OriginalRelief"
{
    Properties
    {
        _MainTex("Original RGBA",2D)="white" {}
        _Tint("Original tint",Color)=(1,1,1,1)
        _HairCards("Hair surface",Float)=0
        _Wind("Hair wind",Float)=.15
        _Outline("Source texel outline",Float)=0
        _CapeEnabled("Analytic cape",Float)=0
        _Breath("Foot pinned breathing",Float)=0
        _AtlasRect("Atlas top origin",Vector)=(0,1,1,1)
        _PaintSize("World width height pixel",Vector)=(1,1,.02,0)
        _Anchor("World foot anchor",Vector)=(.5,1,0,0)
        _HairRect("Pose hair rectangle",Vector)=(0,0,1,.3)
    }
    SubShader
    {
        Tags {"RenderPipeline"="UniversalPipeline" "Queue"="Transparent" "RenderType"="Transparent"}
        Pass
        {
            Tags {"LightMode"="UniversalForwardOnly"}
            Cull Off
            Blend SrcAlpha OneMinusSrcAlpha
            ZWrite Off
            HLSLPROGRAM
            #pragma vertex ReliefVert
            #pragma fragment ReliefFrag
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN
            #pragma multi_compile_fragment _ _SHADOWS_SOFT
            #include "OriginalRelief.hlsl"
            ENDHLSL
        }
        Pass
        {
            Tags {"LightMode"="DepthOnly"}
            Cull Off
            ZWrite On
            ColorMask 0
            HLSLPROGRAM
            #pragma vertex ReliefVert
            #pragma fragment DepthFrag
            #include "OriginalRelief.hlsl"
            half4 DepthFrag(V i):SV_Target
            {float alpha=SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex,ClampUV(i.uv)).a*_Tint.a;if(_HairCards>.5)alpha*=HairMask(i.card);clip(alpha-.12);return 0;}
            ENDHLSL
        }
        Pass
        {
            Tags {"LightMode"="ShadowCaster"}
            Cull Off
            ZWrite On
            ZTest LEqual
            ColorMask 0
            HLSLPROGRAM
            #pragma vertex ShadowVert
            #pragma fragment ShadowFrag
            #include "OriginalRelief.hlsl"
            float3 _LightDirection;
            V ShadowVert(A input)
            {
                V o=ReliefVert(input);float3 world=ApplyShadowBias(o.world,normalize(o.normal),_LightDirection);o.p=TransformWorldToHClip(world);
                #if UNITY_REVERSED_Z
                o.p.z=min(o.p.z,UNITY_NEAR_CLIP_VALUE);
                #else
                o.p.z=max(o.p.z,UNITY_NEAR_CLIP_VALUE);
                #endif
                return o;
            }
            half4 ShadowFrag(V i):SV_Target
            {float alpha=SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex,ClampUV(i.uv)).a*_Tint.a;if(_HairCards>.5)alpha*=HairMask(i.card);clip(alpha-.2);return 0;}
            ENDHLSL
        }
    }
}
