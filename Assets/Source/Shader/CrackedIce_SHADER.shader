Shader "Cracked Ice" {
    Properties {
        _Color ("Color", Color) = (1,1,1,1)
        _MainTex ("Albedo (RGB)", 2D) = "white" {}
        _CracksStrength("Cracks Fade Strength", vector) = (0.0, .75, .45, .25)
        _Glossiness ("Smoothness", Range(0,1)) = 0.5
        _Metallic ("Metallic", Range(0,1)) = 0.0

        _Normal("Normal Texture", 2D) = "blue" {}
        _Roughness("Roughness Texture", 2D) = "black" {}
        _RoughnessStrength("Roughness Strength", float) = 0.5
        _Layers("Crack Layers", 2D) = "white" {}
        _OffsetScale("Offset Scale", float) = 0.5
    }
    SubShader {
        Tags { "RenderType"="Opaque" }

        CGPROGRAM
        #pragma surface surf Standard fullforwardshadows vertex:vert
        #pragma target 3.0

        sampler2D _MainTex;
        sampler2D _Normal;
        sampler2D _Roughness;
        sampler2D _Layers;

        half4 _CracksStrength;
        fixed _RoughnessStrength;
        fixed _OffsetScale;

        struct Input
        {
            float2 uv_MainTex;
            float2 uv_Layers;
            float2 uv_Normal;
            float2 uv_Roughness;
            float3 viewDirTangent;
        };

        half _Glossiness;
        half _Metallic;
        fixed4 _Color;

        UNITY_INSTANCING_BUFFER_START(Props)
        UNITY_INSTANCING_BUFFER_END(Props)

        float4 blendMultiply (float4 baseTex, float4 blendTex, float opacity) {
            float4 baseBlend = baseTex * blendTex;
            return lerp(baseTex, baseBlend, opacity);
        }

        void vert(inout appdata_full v, out Input o) {
            UNITY_INITIALIZE_OUTPUT(Input, o);

            // [VIEW DIRECTION IN TANGENT SPACE] : In order for parallax to work correctly, we need to find
            //  view direction of the camera in tangent space. Calculation below takes care of that.
            // Credit: Harry Alisavakis
            float4 objCam = mul(unity_WorldToObject, float4(_WorldSpaceCameraPos, 1.0));
            float3 viewDir = v.vertex.xyz - objCam.xyz;
            float tangentSign = v.tangent.w * unity_WorldTransformParams.w;
            float3 bitangent = cross(v.normal.xyz, v.tangent.xyz) * tangentSign;
            o.viewDirTangent = float3(
                dot(viewDir, v.tangent.xyz),
                dot(viewDir, bitangent.xyz),
                dot(viewDir, v.normal.xyz)
            );
        }

        void surf (Input IN, inout SurfaceOutputStandard o) {
            fixed4 mainTex = tex2D(_MainTex, IN.uv_MainTex) * _Color;

            fixed3 normal = UnpackNormal(tex2D(_Normal, IN.uv_Normal));
            fixed roughness = tex2D(_Roughness, IN.uv_Roughness).r * _RoughnessStrength;

            fixed parallax = 0;
            for (int j = 0; j < 4; j ++) {
                float ratio = (float) j / 4;

                if (j == 0)
                {
                    // I don't want to show the first layer, because this would be flat on the object (no depth),
                    //   I want to start with the second iteration of the parallax effect, which will have depth.
                }
                else if (j == 1)
                {
                    // First layer of cracks.
                    parallax += tex2D(_Layers, IN.uv_Layers + lerp(0, _OffsetScale, ratio) * normalize(IN.viewDirTangent) + normal).g * _CracksStrength.y;
                }
                else if (j == 2)
                {
                    // Second layer of cracks.
                    parallax += tex2D(_Layers, IN.uv_Layers + lerp(0, _OffsetScale, ratio) * normalize(IN.viewDirTangent) + normal).b * _CracksStrength.z;
                }
                else if (j == 3)
                {
                    // Third layer of cracks.
                    parallax += tex2D(_Layers, IN.uv_Layers + lerp(0, _OffsetScale, ratio) * normalize(IN.viewDirTangent) + normal).r * _CracksStrength.w;
                }
            }
            parallax *= 1.5;

            fixed4 blended = blendMultiply(mainTex, parallax, 0.55);

            o.Albedo = blended.rgb;
            o.Normal = normal;
            o.Metallic = _Metallic;
            o.Smoothness = 1 - roughness;
            o.Alpha = blended.a;
        }
        ENDCG
    }

    FallBack "Diffuse"
}
