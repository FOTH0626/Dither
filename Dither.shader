Shader"Dither"
{
    Properties
    {
        [HideInInspector]  _MainTex("Texture",2D) = "white"{}
        [NoScaleOffset] _NoiseTex("NoiseTex",2D) = "white"{}
        _DitherScaleParam ("Dither Scale",Float) = 1
        _ScaleParam ("Scale",Float) = 1
        _PixelCount("Pixel Count",Int) = 256
        _Threshold("Threshold",Float) = 0.5
        
        _DarkThreshold("Dark Threshold", Range(0,1)) = 0.1
        _LightThreshold("Light Threshold", Range(0,1)) = 0.1
        _DarkColor ("Dark Color", Color) = (0.0,0.0,0.0,1.0)
        _MiddleColor("Middle Color", Color) = (0.0,1.0,1.0,1.0)
        _LightColor("Light Color", Color)= (1.0,1.0,1.0,1.0)

        _ScanLineAngle("ScanLineAngle", Range(0,6.28318)) = 0
        _ScanLineOffset("ScanLineOffset", Range(-5,5)) = 0
    }
    SubShader
    {
        Tags {"RenderPipeline" = "UniversalPipeline"}
        Cull Off
        ZWrite Off
        ZTest Always
        
        HLSLINCLUDE

        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

        float3 overlay(float3 base, float3 blend)
        {
            float3 limit = step(0.5, base);
            return lerp(2.0 * base * blend, 1.0 - 2.0 * (1.0 - base) * (1.0 - blend), limit);
        }

        struct Attributes
        {
            float4 vertex: POSITION;
            float2 uv : TEXCOORD0;
        };

        struct Varyings
        {
            float2 uv :TEXCOORD0;
            float4 vertex: SV_POSITION;
        };

        TEXTURE2D(_MainTex);
        SAMPLER(sampler_MainTex);

        TEXTURE2D(_NoiseTex);
        SAMPLER(sampler_NoiseTex);

        CBUFFER_START(UnityPerMaterial)
            float _DitherScaleParam;
            float _ScaleParam;
            float _PixelCount;
            float _DarkThreshold;
            float _LightThreshold;
            float4 _DarkColor;
            float4 _MiddleColor;
            float4 _LightColor;
            float _ScanLineAngle;
            float _ScanLineOffset;
        CBUFFER_END

        Varyings vertex ( Attributes input)
        {
            Varyings output;

            output.uv = input.uv;
            output.vertex = TransformObjectToHClip(input.vertex);

            return output;
        }

        float4 fragment(Varyings input):SV_Target
        {   //init
            float2 uv = input.uv;
            int2 resolutionSize = _ScreenParams.xy;
            float ratio = (float)resolutionSize.x/resolutionSize.y;
            int pixelCount = _PixelCount;

            if (_DitherScaleParam < 1)
            {
                _DitherScaleParam = 1;
            }
            if (_ScaleParam < 1)
            {
                _ScaleParam = 1;
            }
            _DitherScaleParam = floor(_DitherScaleParam);
            _ScaleParam = floor(_ScaleParam);
            
            //dither color
            int2 bayer88size = int2(8,8);
            float scale_x = (float)pixelCount/bayer88size.x;
            float scale_y = scale_x/ratio;

            float ditherScale = 1/ (_DitherScaleParam * _ScaleParam) ;
            scale_x = frac(uv.x*scale_x * ditherScale);
            scale_y = frac(uv.y*scale_y * ditherScale);

            float2 dither_uv = float2(scale_x,scale_y);
            float3 noiseTexColor = SAMPLE_TEXTURE2D(_NoiseTex,sampler_NoiseTex,dither_uv);

            //pixcel
            float x_pixel_count_scaled = _PixelCount * _ScaleParam;
            float y_pixel_count_scaled = x_pixel_count_scaled/ratio;
            float pixel_uv_x = ceil(uv.x * x_pixel_count_scaled)/x_pixel_count_scaled;
            float pixel_uv_y = ceil(uv.y * y_pixel_count_scaled)/y_pixel_count_scaled;

            float2 pixel_uv = float2(pixel_uv_x,pixel_uv_y);
            float3 baseColor = SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex,pixel_uv).rgb;
            

            float3 overlayColor = overlay(baseColor,noiseTexColor);

            // float averageColor = (overlayColor.r+overlayColor.g+overlayColor.b)/3;
            float luminace = dot(overlayColor, float3(0.299,0.587,0.114));
            
            float isDark = step(luminace,_DarkThreshold);
            float isLight = step(1-_LightThreshold, luminace);
            float4 color = lerp(_MiddleColor, _DarkColor, isDark );
            color = lerp(color, _LightColor, isLight);
            
            // float final = luminace > _Threshold ? 1 :0;
            
            float k = tan(_ScanLineAngle);
            float d = _ScanLineOffset;
            float2 xOyUV = uv * 2 -1;
            float sign = cos(_ScanLineAngle) > 0 ? (xOyUV.y > (k * xOyUV.x +d)? 1 :0 ) : (xOyUV.y < (k * xOyUV.x +d)? 1 :0);
            color = lerp(color,float4(baseColor,1),sign);
            
            return float4 (color.xyz,1);
        }
        
        ENDHLSL
        
        Pass
        {
            Tags
            {
                "RenderPipeline" = "UniversalPipeline"
            }
            Cull Off
            ZWrite Off 
            ZTest Always
            
            HLSLPROGRAM

            #pragma vertex vertex
            #pragma fragment fragment
            
            ENDHLSL
        }
    }
}