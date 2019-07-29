Shader "Zelda/Link_ST_EYE_UV"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
		_ShadowMap("_ShadowMap" , 2D) = "white" {}
		_NormalMap("_NormalMap" , 2D) = "white" {}
		_SpecularMap("_SpecularMap" , 2D) = "white"{}
		_CenterOffY( "_CenterOffY" , Vector ) = (0.01,0.01 ,0,0)	//UV向上偏倚的距离
		_Sec_OffXY("_Sec_OffXY" , Vector) = (0.01,0.01 ,0,0)		//第二个光圈便宜的距离
		_Radius("_Radius" , Range(0,0.4)) = 0.1
		_Sec_Radius("_Sec_Radius" , Range(0,0.3)) = 0.1				//折射光圈的radius
		_LightStrengh("_LightStrengh" , Range(0,0.9)) = 0.6			//Specular强度

		_MoveY_Val("_MoveY_Val" , Range(0.1,0.7)) = 0.3				//上下移动的阈值
		_Be_Reverse_UV_Y("_Be_Reverse_UV_Y" , Range(0,1)) = 0
	}
    SubShader
    {
        Tags { "RenderType"="Opaque" "LightMode" = "ForwardBase"}
        LOD 100

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
			//#pragma multi_compile_fwdbase
			#include "Lighting.cginc"
			#include "AutoLight.cginc"
            #include "UnityCG.cginc"

            struct a2v
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float4 uv : TEXCOORD0;
                float4 pos : SV_POSITION;
				float3 culculate_Normal : TEXCOORD1;
				//float3 worldPos : TEXCOORD2;
				float3 objLightDir : TEXCOORD3;
				float3 objViewDir : TEXCOORD4;
				//SHADOW_COORDS(5)
            };

			sampler2D _MainTex;
			float4 _MainTex_ST;
			sampler2D _ShadowMap;
			float4 _ShadowMap_ST;
			sampler2D _NormalMap;
			float4 _NormalMap_ST;
			sampler2D _SpecularMap;
			float4 _SpecularMap_ST;

			fixed2 _CenterOffY;
			fixed2 _Sec_OffXY;
			fixed _Radius;
			fixed _LightStrengh;
			fixed _Sec_Radius;

			fixed _MoveY_Val;
			fixed _Be_Reverse_UV_Y;

			float Unity_Remap_float(float In, fixed2 InMinMax, fixed2 OutMinMax)
			{
				return OutMinMax.x + (In - InMinMax.x) * (OutMinMax.y - OutMinMax.x) / (InMinMax.y - InMinMax.x);
			}

            v2f vert (a2v v)
            {
                v2f o;
                o.pos = UnityObjectToClipPos(v.vertex);
                o.uv.xy = TRANSFORM_TEX(v.uv, _MainTex);
				o.uv.zw = v.uv;
				//o.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
				o.objLightDir = ObjSpaceLightDir(v.vertex);
				o.objViewDir = ObjSpaceViewDir(v.vertex );

				//如果要反转UVY
				if (_Be_Reverse_UV_Y >= 1)
					o.uv.w = 1 - (-o.uv.w);

				//模型空间中的(0,-1,0)用来进行光照的计算
				o.culculate_Normal = normalize(UnityObjectToWorldNormal(fixed3(0, -1, 0)));

				//TRANSFER_SHADOW(o);

                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
				//计算一个atten
				//UNITY_LIGHT_ATTENUATION(atten, i, i.worldPos);

				//总颜色
				fixed4 col = tex2D(_MainTex, i.uv.xy) * 1.5;


				//用来判断方向正负的向量
				fixed3 d_DirX = fixed3(-1,0,0);
				fixed3 d_DirY = fixed3( 0,0,-1 );
				//用来判断光照方向如果是背向，则不显示高光
				fixed3 normal_Dir = fixed3(0, 1, 0);

				bool b_Specular = true;
				if ( dot(normal_Dir, i.objLightDir) < 0)
					b_Specular = false;

				//SpecularMap 
				if (b_Specular == true )
				{ 
					fixed4 SpecularMap = tex2D(_SpecularMap , i.uv.xy);	
				
					//计算方向是加还是减
					fixed lightOffX = dot(i.objLightDir, d_DirX);
					lightOffX = lightOffX * 0.3;
					fixed lightOffY = dot(i.objLightDir, d_DirY);
					lightOffY = lightOffY * _MoveY_Val;

					//计算根据视线方向的偏倚
					fixed viewDiffDirX = dot(i.objViewDir , d_DirX);
					viewDiffDirX = viewDiffDirX * 0.3;
					fixed viewDiffDirY = dot(i.objViewDir , d_DirY);
					viewDiffDirY = viewDiffDirY * 0.3;

					//计算光圈圆心位置
					fixed2 speCenter = fixed2( 0.5 + _CenterOffY.x ,0.5 + _CenterOffY.y);
					//对角线折射光圈圆心
					fixed2 refrac_speCenter = fixed2(1- speCenter.x + _Sec_OffXY.x,1 - speCenter.y + _Sec_OffXY.y );

					//根据光线的变化，要在计算出来之后再进行！
					speCenter.x += lightOffX + viewDiffDirX;
					speCenter.y += viewDiffDirY + lightOffY;
					/* --！！！！
						对于光线的变化，折射后的角膜的光，与反射的光变化相反！ 
						而对于视线方向的变化，折射后的角膜光与反射的光变化应该是一致的！！
					--！！！ */
					refrac_speCenter.x -= (lightOffX);  
					refrac_speCenter.y -= (lightOffY) * 1.22;
					refrac_speCenter.x += (viewDiffDirX);   //!!!
					refrac_speCenter.y += (viewDiffDirY) * 1.12;

					//使用uv位置化光圈
					fixed r_dis = distance(i.uv.zw, speCenter);
					fixed spe_diff = smoothstep(0.18, 0.25, _Radius - r_dis);

					//折射光圈
					fixed refrac_dis = distance(i.uv.zw, refrac_speCenter);
					fixed spe_refrac_diff = smoothstep(0.18, 0.25, _Sec_Radius - refrac_dis);
					spe_refrac_diff = Unity_Remap_float(spe_refrac_diff, fixed2(0,1) , fixed2(0,0.9));

					col.rgb += (SpecularMap * spe_diff * _LightStrengh);
					col.rgb += (SpecularMap * spe_refrac_diff * _LightStrengh);
				}
				col.rgb *= _LightColor0.xyz;

				//ShadowMap
				fixed4 shadowMap = tex2D(_ShadowMap , i.uv.xy);
				col.rgb = col.rgb * shadowMap.rgb;

				//if (diffDir < 0)
				//	discard;

				//fixed4 col = fixed4(1, 1, 1, 1) * diffDir;
				

                return col;
            }
            ENDCG
        }
    }
}
