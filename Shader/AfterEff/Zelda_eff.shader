Shader "Zelda/Zelda_AfterEff" 
{
	Properties {
		_MainTex ("Albedo (RGB)", 2D) = "white" {}
		_Val("_Val" , Range(0,1)) = 1
		_BrightNess("_BrightNess" , Float) = 1.2
		_Saturate("_Saturate" , Range(0,1)) = 0.5
	}
	SubShader {
		Tags { "RenderType"="Opaque" }
		LOD 200

		ZWrite Off ZTest Off

		Pass{  
            CGPROGRAM  
            #include "UnityCG.cginc"  
            #pragma vertex vert_img  
            #pragma fragment frag  
            uniform sampler2D _MainTex;  

			fixed _Val;
			fixed _BrightNess;
			fixed _Saturate;

            float4 frag( v2f_img o ) : COLOR  
            {  
                fixed4 _color = tex2D(_MainTex, o.uv); 
				
				fixed4 finalcolor = _color * _BrightNess;

				fixed luminance = 0.2125 * _color.r + 0.7154 * _color.g + 0.0721 * _color.b;
				fixed3 luminanceColor = fixed3(luminance, luminance, luminance);
				finalcolor.rgb = lerp(finalcolor.rgb , luminanceColor , _Saturate);

				fixed3 avgColor = fixed3(0.5, 0.5, 0.5);
                //_color = Screen(_color);
				finalcolor.rgb = lerp(finalcolor.rgb, avgColor , _Val);

                return finalcolor;
            }  
            ENDCG  
        }  
	}
	FallBack "Diffuse"
}