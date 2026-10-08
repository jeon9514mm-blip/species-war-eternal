Shader "Eternal/PaintedGroundSeal"
{
    Properties
    {
        _MainTex("Painted moss and bronze seal",2D)="white" {}
        _Opacity("Ground opacity",Range(0,1))=0.58
        _RotationRate("Rotation radians per second",Float)=0.12
    }
    SubShader
    {
        Tags { "RenderPipeline"="UniversalPipeline" "Queue"="Transparent-14" "RenderType"="Transparent" }
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
            TEXTURE2D(_MainTex);SAMPLER(sampler_MainTex);
            CBUFFER_START(UnityPerMaterial)
                float _Opacity;
                float _RotationRate;
            CBUFFER_END
            struct A {float4 p:POSITION;float2 uv:TEXCOORD0;};
            struct V {float4 p:SV_POSITION;float2 uv:TEXCOORD0;};
            V Vert(A i){V o;o.p=TransformObjectToHClip(i.p.xyz);o.uv=i.uv;return o;}
            half4 Frag(V i):SV_Target
            {
                float angle=_Time.y*_RotationRate,s=sin(angle),c=cos(angle);
                float2 p=i.uv-0.5;
                float2 uv=float2(p.x*c-p.y*s,p.x*s+p.y*c)+0.5;
                if(any(uv<0)||any(uv>1))return 0;
                half4 paint=SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex,uv);
                paint.rgb*=1.05;
                paint.a*=_Opacity*(0.9+0.1*sin(_Time.y*0.8));
                return paint;
            }
            ENDHLSL
        }
    }
}
