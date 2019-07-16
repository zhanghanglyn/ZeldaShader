/*
色块大面积分层（头发有三层，其余两层）
菲涅尔边框效果 （正，反，在光亮处的效果与暗处可叠加，并且有偏移）
高光可由画笔替代

分析贴图之后法线，绿色通道用来处理金属高光！所以
*/

Shader "Zelda/LinkUtil_ST"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
		_NormalMap("_NormalMap" , 2D) = "black" {}
		_DabsTex("_DabsTex" , 2D) = "white" {}
		_SPecularMap("_SPecularMap" , 2D) = "white"{}
		_AOMap("_AOMap" , 2D) = "white"{}

		_BeUseObjNormal("_BeUseObjNormal" , Range(0,1)) = 0			//是否进行法线融合
		_BeNormalBlend("_BeNormalBlend" , Range(0,1)) = 0			//是否使用物体本身法线
		_ShadowLayerVal("_ShadowLayerVal" , Range(0,1)) = 0.25		//阴影分层位置
		_LayerRemapVal("_LayerRemapVal" , Vector) = (0.2,0.9,0,0)	//分层后remap等级
		_BeDabs("_BeDabs" , Range(0,1)) = 1							//是否将高光替换笔刷

		_SpecularSize("_SpecularSize" , Float) = 0.1				//高光宽度
		_SpecularPower("_SpecularPower" , Range(0,1)) = 0.1			//高光强度
		_ShadowStep("_ShadowStep" , Range(0,1)) = 0.7				//阴影分层阈值
		_DabsSizeX("_DabsSizeX" , Float) = 2						//将50除以该值，作为tilling的UV值
		_DabsSizeY("_DabsSizeY" , Float) = 2						//将50除以该值，作为tilling的UV值
		_DabsRotation("_DabsRotation" , Float) = 30					//UV的旋转角度

		//_FresnelScale("_FresnelScale" , Range(0,1)) = 0			//菲涅尔控制系数
		_FresnelPow("_FresnelPow" , Float)	=	8					//菲涅尔pow系数
		_DarkFresnelPow("_DarkFresnelPow" , Float) = 3				//暗面菲涅尔pow
		_FresnelColorVal("_FresnelColorVal" , Range(0,1)) = 0.4		//该值越小，越接近物体本身的颜色

		_AmbientVal("_AmbientVal" , Range(0,1.2)) = 0.3				//环境光系数

		_BeUseMetallicMap("_BeUseMetallicMap" , Range(0,1)) = 0		//是否使用SPC的G通道做金属贴图
		_MetallicBoundVal("_MetallicBoundVal" , Range(0.01,1))	=	0.4			//金属度缩小值
		_MetallicVal("_MetallicVal" , Range(0,1)) = 0.5				//金属高光值
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 100

		//Cull Off

		CGINCLUDE
		////////////////////////////////////////
		///////////计算函数相关/////////////////
			//法线融合
			float3 Unity_NormalBlend_float(float3 A, float3 B)
			{
				return normalize(float3(A.rg + B.rg, A.b * B.b));
			}
			float3 Unity_NormalBlend_Reoriented_float(float3 A, float3 B)
			{
				float3 t = A.xyz + float3(0.0, 0.0, 1.0);
				float3 u = B.xyz * float3(-1.0, -1.0, 1.0);
				return (t / t.z) * dot(t, u) - u;
			}
			//Remap
			float4 Unity_Remap_float4(float4 In, float2 InMinMax, float2 OutMinMax)
			{
				return OutMinMax.x + (In - InMinMax.x) * (OutMinMax.y - OutMinMax.x) / (InMinMax.y - InMinMax.x);
			}
			float Unity_Remap_float(float In, fixed2 InMinMax, fixed2 OutMinMax)
			{
				return OutMinMax.x + (In - InMinMax.x) * (OutMinMax.y - OutMinMax.x) / (InMinMax.y - InMinMax.x);
			}

			//卡通分层 , layerCount 可以有两层和三层
			fixed SetToonLayer(fixed diff , fixed layerCount , fixed _ShadowLayerVal ,fixed2 _LayerRemapVal)
			{
				if (layerCount == 2)
				{
					diff = smoothstep(_ShadowLayerVal, _ShadowLayerVal + 0.01, diff);
					diff = Unity_Remap_float(diff , fixed2(0,1) , _LayerRemapVal.xy);
				}
				else if (layerCount == 3)
					diff = smoothstep(_ShadowLayerVal, _ShadowLayerVal + 0.01, diff);

				return diff;
			}

			//旋转UV
			fixed2 Rotate_Degrees_float(float2 UV, float2 Center, float Rotation)
			{
				Rotation = Rotation * (3.1415926f / 180.0f);
				UV -= Center;
				float s = sin(Rotation);
				float c = cos(Rotation);
				float2x2 rMatrix = float2x2(c, -s, s, c);
				rMatrix *= 0.5;
				rMatrix += 0.5;
				rMatrix = rMatrix * 2 - 1;
				UV.xy = mul(UV.xy, rMatrix);
				UV += Center;
				return UV;
			}

		////////////////////////////////////////
		////////////////////////////////////////
		ENDCG

        Pass
        {
			Tags {"LightMode" = "ForwardBase"}

            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
			#pragma multi_compile_fwdbase
            #include "UnityCG.cginc"
			#include "Lighting.cginc"
			#include "AutoLight.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
				float3 normal : NORMAL;
				float4 tangent : TANGENT;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float4 uv : TEXCOORD0;
                float4 pos : SV_POSITION;
				SHADOW_COORDS(1)
				float4 Tan_T_World_M_1 : TEXCOORD2;
				float4 Tan_T_World_M_2 : TEXCOORD3;
				float4 Tan_T_World_M_3 : TEXCOORD4;
				float4 Tan_T_World_M_4 : TEXCOORD5;
				float4 uv2 : TEXCOORD6;
            };

            sampler2D _MainTex;
            float4 _MainTex_ST;
			sampler2D _NormalMap;
			float4 _NormalMap_ST;
			sampler2D _SPecularMap;
			float4 _SPecularMap_ST;
			sampler2D _DabsTex;
			float4 _DabsTex_ST;
			sampler2D _AOMap;
			float4 _AOMap_ST;

			fixed _BeNormalBlend;	//是否进行法线融合
			fixed _BeUseObjNormal;	//是否使用物体本身法线
			fixed _ShadowLayerVal;	//阴影分层位置
			fixed4 _LayerRemapVal;	//分层后remap等级
			fixed _BeDabs;
			fixed _SpecularSize;
			fixed _SpecularPower;
			fixed _ShadowStep;
			fixed _DabsSizeX;
			fixed _DabsSizeY;
			fixed _DabsRotation;
			//fixed _FresnelScale;
			fixed _FresnelPow;
			fixed _FresnelColorVal;
			fixed _AmbientVal;
			fixed _DarkFresnelPow;
			fixed _BeUseMetallicMap;
			fixed _MetallicVal;
			fixed _MetallicBoundVal;

            v2f vert (appdata v)
            {
                v2f o;
                o.pos = UnityObjectToClipPos(v.vertex);
                o.uv.xy = TRANSFORM_TEX(v.uv, _MainTex);
				o.uv.zw = TRANSFORM_TEX(v.uv, _NormalMap);
				o.uv2.xy = TRANSFORM_TEX(v.uv, _SPecularMap);

				float4 worldPos = mul(unity_ObjectToWorld, v.vertex);

				//计算法线，切线和副切线并且生成转换矩阵
				float3 worldTangent = normalize(mul((float3x3)unity_ObjectToWorld, v.tangent));
				float3 worldNormal = UnityObjectToWorldNormal(v.normal);//normalize(mul(v.normal, (float3x3)unity_WorldToObject));
				float3 world_binormal = cross(worldNormal, worldTangent) * v.tangent.w;

				o.Tan_T_World_M_1 = float4(worldTangent.x, world_binormal.x, worldNormal.x ,worldPos.x);
				o.Tan_T_World_M_2 = float4(worldTangent.y, world_binormal.y, worldNormal.y, worldPos.y);
				o.Tan_T_World_M_3 = float4(worldTangent.z, world_binormal.z, worldNormal.z, worldPos.z);

				//shadow coordinates to pixel shader
				TRANSFER_SHADOW(o);

                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
				//计算从切线空间到世界空间的矩阵
				float3 worldPos = float3(i.Tan_T_World_M_1.w,i.Tan_T_World_M_2.w,i.Tan_T_World_M_3.w);
				float3x3 Matrix_TanToWorld = float3x3(i.Tan_T_World_M_1.xyz, i.Tan_T_World_M_2.xyz,i.Tan_T_World_M_3.xyz);
				
				//获取传入的法线
				float3 tangent_normal = UnpackNormal(tex2D(_NormalMap, i.uv.zw)).rgb;
				float3 worldNormal_From_Map = normalize( mul(Matrix_TanToWorld, tangent_normal));
				float3 worldNormal_From_Obj = float3(i.Tan_T_World_M_1.z, i.Tan_T_World_M_2.z, i.Tan_T_World_M_3.z);

				//计算最后使用的法线
				float3 worldNormal = worldNormal_From_Map;
				if (_BeUseObjNormal >= 1)
					worldNormal = worldNormal_From_Obj;
				if (_BeNormalBlend >= 1)
					worldNormal = Unity_NormalBlend_Reoriented_float(worldNormal_From_Map, worldNormal_From_Obj);
				
				//获取光照方向
				float3 worldLightDir = normalize( UnityWorldSpaceLightDir(worldPos) );
				//获取视线方向
				float3 worldViewDir = normalize( UnityWorldSpaceViewDir(worldPos) );
				//半角向量
				float3 halfDir = worldLightDir + worldViewDir;
				//光照颜色
				fixed3 LightColor = _LightColor0.xyz;

				//不将AO在最后乘上增加细节，而是用来乘以法线！可以完美显示效果 但是最好能够颜色加深,在Add光照中？
				//尝试 将AO与Normal进行相乘！可以将着色效果不再生硬
				fixed3 ao;
				ao = tex2D(_AOMap, i.uv.xy).rgb;
				worldNormal *= ao.r;

				//根据法线计算初步光照并且Toon分层
				fixed diff = dot(worldLightDir, worldNormal);
				fixed temp_diff = diff;		//保存用来计算阴影
				diff = SetToonLayer(diff, 2, _ShadowLayerVal, _LayerRemapVal);

				//阴影以及环境光atten  //想要让阴影在本身就是阴影的地方不显示！
				//fixed atten = SHADOW_ATTENUATION(i);
				UNITY_LIGHT_ATTENUATION(atten, i, worldPos);
				atten = smoothstep(_ShadowStep, _ShadowStep + 0.01, atten);
				//保存一个纯光照衰减
				fixed save_atten = atten;

				//temp_diff = step(_ShadowLayerVal, temp_diff);//把temp_diff最原始的状态保存起来
				atten = atten * step(_ShadowLayerVal, temp_diff);//atten * temp_diff;
				//此步骤的目的在于使模型背后背光的地方，不会变全黑而是显示正常贴图
				diff = atten + diff;
				diff = Unity_Remap_float(diff, fixed2(0, 1), fixed2(0.4, 0.7));

				//获取Specular贴图
				fixed3 SpecularMap = tex2D(_SPecularMap , i.uv2.xy).rgb;
				fixed Specular = smoothstep(0.3, 0.32 ,SpecularMap.r);

				//保存一个dot(View , worldNormal)免得重复计算
				fixed view_normal_dot = dot(worldViewDir, worldNormal);

				//保存一个半角向量和Normal
				fixed half_normal_dot = dot(halfDir, worldNormal);

				//////////////////////////////////
				////计算高光，以及将高光转化为笔刷
				fixed3 specular = fixed3(1, 1, 1);
				//保存一个当前的specular高光范围，并且与金属度相乘显示金属效果，不与specular用同一参数控制
				fixed metallicSpecularDiff;
				//如果只使用普通的高光
				if (_BeDabs < 1)
				{
					fixed specular_Normal = half_normal_dot * diff * Specular;//half_normal_dot * atten * SpecularMap;
					specular_Normal = Unity_Remap_float(specular_Normal, fixed2(0.9, 1), fixed2(0, 1));

					metallicSpecularDiff = specular_Normal;

					specular_Normal = step((1 - _SpecularSize), specular_Normal);
					//smoothstep((1 - _SpecularSize), (1 - _SpecularSize) + 0.1, specular_Normal);
					specular_Normal *= _SpecularPower;
					specular = specular_Normal * fixed3(1, 1, 1);
				}
				else	////如果需要使用笔刷，则将高光转化为笔刷
				{
					//计算笔刷的缩放以及旋转
					fixed2 dabsUv = fixed2(i.uv.x * (_DabsSizeX), i.uv.y * 10 * (_DabsSizeY));
					dabsUv = Rotate_Degrees_float(dabsUv, fixed2(0.5,0.5), _DabsRotation);
					fixed3 DabsMap = tex2D(_DabsTex, dabsUv).rgb;

					fixed specularScope = half_normal_dot * diff * Specular;//half_normal_dot * atten * SpecularMap;

					metallicSpecularDiff = specularScope;

					fixed temp_shadowDiff = Unity_Remap_float(_SpecularSize, fixed2(0, 1), fixed2(-1, -0.9));
					temp_shadowDiff = temp_shadowDiff + specularScope;
					//temp_shadowDiff = smoothstep(0.01, 0.15, temp_shadowDiff);
					temp_shadowDiff = smoothstep(0.01, 0.02, temp_shadowDiff);
					temp_shadowDiff *= _SpecularPower;
					specular = DabsMap * temp_shadowDiff;
				}
				///////////////////////////////////

				////金属度贴图
				fixed metallic = SpecularMap.g;
				metallic *= diff * metallicSpecularDiff;
				metallic = step(_MetallicBoundVal, metallic);
				metallic *= _MetallicVal;

				////添加光照面菲涅尔效应，只有光面
				fixed fresnel = pow(1 - max(0, dot(worldViewDir, worldNormal)), _FresnelPow);
				fresnel *= (half_normal_dot * atten);
				fresnel  = smoothstep(0.01, 0.02, fresnel);

				///添加暗面菲涅尔效应 描边？
				/*fixed fresnel_dark = 1 - dot(worldViewDir, worldNormal);
				fresnel_dark = step(0.5 , fresnel_dark);
				fresnel_dark = step((1 - fresnel) , fresnel_dark);
				fresnel_dark *= (1 - save_atten);
				fresnel_dark = smoothstep(0.01, 0.02, fresnel_dark);*/

				/////////////////////尝试使用新的菲涅尔效应/////////////////////////
				
				float3 viewForward = float3(worldViewDir.x, 1, 1);  //尝试只使用X方向的向量，让边缘光与视线的倾斜角度无关
				//fixed fresnel2 = pow((1.0 - saturate(dot(worldNormal, viewForward))), _DarkFresnelPow);
				fixed fresnel2 = pow((1.0 - saturate(dot(worldNormal, worldViewDir))), _DarkFresnelPow);
				
				fixed3 light_F = worldLightDir * -1;
				light_F = fixed3(worldLightDir.x, 1, 1);
				fixed F_diff = 1 - saturate(dot(light_F , worldViewDir) + 0.2) + 0.2;

				//暗面
				fixed dark_fresnel = step((F_diff + 0.1), fresnel2);
				fixed f_tempdiff = SetToonLayer(temp_diff, 2, _ShadowLayerVal, _LayerRemapVal);
				dark_fresnel *= f_tempdiff;
				dark_fresnel = saturate(dark_fresnel);

				/*fixed3 diffColor = LightColor * specular * f_tempdiff;
				fixed4 diffuseColor = tex2D(_MainTex, i.uv.xy);
				diffuseColor.rgb = diffColor.rgb * (diffuseColor.rgb * LightColor);
				diffuseColor *= 1.5;
				diffuseColor += dark_fresnel;
				fixed4 col = diffuseColor;*/
				
				///////////////////////////////////////////////////////////////////
				diff = diff + fresnel;
				fixed4 diffuseColor = tex2D(_MainTex, i.uv.xy);
				diffuseColor.rgb += specular;
				diffuseColor.rgb = diffuseColor.rgb * diff * LightColor;
				if (_BeUseMetallicMap)
					diffuseColor.rgb += (diffuseColor.rgb * _MetallicVal * diff * LightColor * metallic);
				diffuseColor *= 1.5;
				diffuseColor += (fresnel * _FresnelColorVal);
				diffuseColor += (dark_fresnel * 2);

				fixed4 col = fixed4(diffuseColor.rgb + UNITY_LIGHTMODEL_AMBIENT.xyz * _AmbientVal, 1);

                // Albedo满反色颜色整合
                /*fixed4 diffuseColor = tex2D(_MainTex, i.uv.xy);
				diffuseColor.rgb = diffuseColor.rgb * diff * LightColor;// *ao;
				fresnel = (fresnel * diffuseColor / 2 * 10);
				diffuseColor += fresnel + dark_fresnel;

				fixed4 col = fixed4(((LightColor * specular ) + diffuseColor.rgb) + UNITY_LIGHTMODEL_AMBIENT.xyz * 0.3, 1);
				*/
				///test
				//fixed4 col = fixed4( fixed3(1,1,1) * ao.r, 1);

				return col;
            }
            ENDCG
        }

		//初步设计 PASS块用来显示笔刷以及AO阴影效果叠加
		/*Pass {
			Tags {"LightMode" = "ForwardAdd"}

			Blend srcAlpha OneMinusSrcAlpha

			CGPROGRAM
			#pragma vertex vert_add
			#pragma fragment frag_add
			#include "UnityCG.cginc"
			#include "Lighting.cginc"
			#include "AutoLight.cginc"
			#pragma multi_compile_fwdadd
			
			struct a2v
			{
				float4 vertex : POSITION;
				float2 uv : TEXCOORD0;
			};

			struct v2f {
				float2 uv : TEXCOORD0;
				float4 pos : SV_POSITION;
				float4 world_pos : TEXCOORD1;
			};

			sampler2D _MainTex;
			float4 _MainTex_ST;

			v2f vert_add(a2v v)
			{
				v2f o;
				o.pos = UnityObjectToClipPos(v.vertex);
				o.uv = TRANSFORM_TEX(v.uv, _MainTex);
				o.world_pos = mul(unity_ObjectToWorld, v.vertex);

				return o;
			}

			fixed4 frag_add(v2f i) : SV_Target
			{
				///计算光照方向，因为可能并不是方向光
				//#ifndef USING_LIGHT_MULTI_COMPILE
				//fixed3 worldLightDir = normalize(_WorldSpaceLightPos0.xyz - o.world_pos.xyz * _WorldSpaceLightPos0.w);
				//#else
				//#ifdef USING_DIRECTIONAL_LIGHT
				//fixed3 worldLightDir = normalize(_WorldSpaceLightPos0.xyz);
				//#else
				//fixed3 worldLightDir = normalize(_WorldSpaceLightPos0.xyz - o.world_pos.xyz);
				//#endif
				//#endif
				//fixed3 worldLightDir = UnityWorldSpaceLightDir(o.world_pos);

				//计算光的衰减 如果不是方向光则使用光强衰弱纹理
				#ifdef USING_DIRECTIONAL_LIGHT
							fixed atten = 1.0;
				#else
							//float3 lightCoord = mul(unity_WorldToLight , float4(o.world_pos.xyz,1) ).xyz;
							//fixed atten = tex2D( _LightTexture0 , dot( lightCoord, lightCoord).rr ).UNITY_ATTEN_CHANNEL;
				#if defined (POINT)
							float3 lightCoord = mul(unity_WorldToLight, float4(i.world_pos.xyz, 1)).xyz;
							fixed atten = tex2D(_LightTexture0, dot(lightCoord, lightCoord).xx).UNITY_ATTEN_CHANNEL;
							//fixed atten = tex2D(_LightTexture0, float2(dot(lightCoord, lightCoord), dot(lightCoord, lightCoord))).UNITY_ATTEN_CHANNEL;
				#elif defined (SPOT)
							float4 lightCoord = mul(unity_WorldToLight, float4(i.world_pos.xyz, 1));
							fixed atten = (lightCoord.z > 0) * tex2D(_LightTexture0, lightCoord.xy / lightCoord.w + 0.5).w * tex2D(_LightTextureB0, dot(lightCoord, lightCoord).rr).UNITY_ATTEN_CHANNEL;
				#else
							fixed atten = 1.0;
				#endif				
				#endif

				fixed3 albedo = _Color.rgb * tex2D(_MainTex , i.uv).xyz;

				fixed3 diffuse = albedo * _LightColor0.xyz * saturate(dot(o.worldNormal , worldLightDir));

				fixed3 viewDir = normalize(_WorldSpaceCameraPos.xyz - o.world_pos.xyz);
				fixed3 worldView = normalize(UnityWorldSpaceViewDir(o.world_pos));

				fixed3 halfDir = normalize(worldView + worldLightDir);//_WorldSpaceLightPos0.xyz);

				fixed3 specular = _Specular.xyz * _LightColor0.xyz * pow(saturate(dot(o.worldNormal, halfDir)), _Gloss);

				fixed3 color = (diffuse + specular) * atten;
				return fixed4(color,1);
			}
			ENDCG
		}*/

		Pass {
			Tags {"LightMode"="ShadowCaster"}

			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#pragma multi_compile_shadowcaster
			#include "UnityCG.cginc"

			struct a2v {
				float4 vertex : POSITION;
				float2 uv : TEXCOORD0;
				float3 normal : NORMAL;
			};
			struct v2f
			{
				//float2 uv : TEXCOORD0;
				//float4 pos : SV_POSITION;
				V2F_SHADOW_CASTER;
			};

			v2f vert(a2v v)
			{
				v2f o;

				TRANSFER_SHADOW_CASTER_NORMALOFFSET(o);
				return o;
			}
			fixed4 frag(v2f i) : SV_Target
			{
				SHADOW_CASTER_FRAGMENT(i);
			}

			ENDCG
		}
    }
}
