﻿Shader "EVE/CloudShadow" {
	Properties{
		_Color("Color Tint", Color) = (1,1,1,1)
		_MainTex("Main (RGB)", 2D) = "white" {}
		_DetailTex("Detail (RGB)", 2D) = "white" {}
		_DetailScale("Detail Scale", float) = 100
		_DetailDist("Detail Distance", Range(0,1)) = 0.00875
		_PlanetOrigin("Sphere Center", Vector) = (0,0,0,1)
		_SunDir("Sunlight direction", Vector) = (0,0,0,1)
		_Radius("Radius", Float) = 1
		_PlanetRadius("Planet Radius", Float) = 1
		_ShadowFactor("Shadow Factor", Float) = 1
	}
	SubShader{
		Pass {
			Blend Zero SrcColor
			ZWrite Off
			Offset -.25, -.25
			CGPROGRAM
			#include "EVEUtils.cginc"
			#pragma target 3.0
			#pragma glsl
			#pragma vertex vert
			#pragma fragment frag
			#pragma multi_compile WORLD_SPACE_OFF WORLD_SPACE_ON
			#pragma multi_compile MainTex CUBE_MainTex 
			#pragma multi_compile ALPHAMAP_NONE_MainTex ALPHAMAP_R_MainTex ALPHAMAP_G_MainTex ALPHAMAP_B_MainTex ALPHAMAP_A_MainTex

#ifdef CUBE_MainTex
			uniform samplerCUBE cube_MainTex;
#elif defined (CUBE_RGB2_MainTex)
			sampler2D cube_MainTexPOS;
			sampler2D cube_MainTexNEG;
#else
			sampler2D _MainTex;
#endif

#ifndef ALPHAMAP_NONE_MainTex
			half4 ALPHAMAP_MainTex;
#endif
			fixed4 _Color;
			uniform sampler2D _DetailTex;
			fixed4 _DetailOffset;
			float _DetailScale;
			float _DetailDist;
			float4 _SunDir;
			float _Radius;
			float _PlanetRadius;
			float _ShadowFactor;

			float3 _PlanetOrigin;
			uniform float4x4 _Projector;

			struct appdata_t {
				float4 vertex : POSITION;
				float3 normal : NORMAL;
			};

			struct v2f {
				float4 pos : SV_POSITION;
				float4 posProj : TEXCOORD0;
				float shadowCheck : TEXCOORD1;
				float originDist : TEXCOORD2;
				float4 worldPos : TEXCOORD3;
				float3 mainPos : TEXCOORD4;
				float3 detailPos : TEXCOORD5;
			};

			v2f vert(appdata_t v)
			{
				v2f o;
				o.posProj = mul(_Projector, v.vertex);
				o.pos = mul(UNITY_MATRIX_MVP, v.vertex);

				o.worldPos = mul(_Object2World, v.vertex);
#ifdef WORLD_SPACE_ON
				float4 vertexPos = o.worldPos;
				float3 worldOrigin = _PlanetOrigin;
#else
				float4 vertexPos = v.vertex;
				float3 worldOrigin = float3(0,0,0);
#endif


				float3 L = worldOrigin - vertexPos.xyz;
				o.originDist = length(L);
				float tc = dot(L,-_SunDir);
				float ntc = dot(normalize(L), _SunDir);
				float d = sqrt(dot(L,L) - (tc*tc));
				float d2 = pow(d,2);
				float td = sqrt(dot(L,L) - d2);
				float sphereRadius = _Radius;
				o.shadowCheck = step(o.originDist, sphereRadius)*saturate(ntc*100);
				//saturate((step(d, sphereRadius)*step(0.0, tc))+
				//(step(o.originDist, sphereRadius)));
				float tlc = sqrt((sphereRadius*sphereRadius) - d2);
				float sphereDist = lerp(lerp(tlc - td, tc - tlc, step(0.0, tc)),
				lerp(tlc - td, tc + tlc, step(0.0, tc)), step(o.originDist, sphereRadius));
				float4 planetPos = vertexPos + (-_SunDir*sphereDist);
				planetPos = (mul(_MainRotation, planetPos));
				o.mainPos = planetPos.xyz;
				o.detailPos = (mul(_DetailRotation, planetPos)).xyz;
				return o;
			}

			fixed4 frag(v2f IN) : COLOR
			{
				half shadowCheck = step(0, IN.posProj.w)*IN.shadowCheck;

				//Ocean filter
#ifdef WORLD_SPACE_ON
				shadowCheck *= saturate(.2*((IN.originDist + 5) - _PlanetRadius));
#endif

#ifdef CUBE_MainTex
				half4 main = GetSphereMapCube(cube_MainTex, IN.mainPos);
#elif defined (CUBE_RGB2_MainTex)
				half4 main = GetSphereMapCube(cube_MainTexPOS, cube_MainTexNEG, IN.mainPos);
#else
				half4 main = GetSphereMap(_MainTex, IN.mainPos);
#endif

#ifdef ALPHAMAP_R_MainTex
				main = half4(1, 1, 1, main.r);
#elif ALPHAMAP_G_MainTex
				main = half4(1, 1, 1, main.g);
#elif ALPHAMAP_B_MainTex
				main = half4(1, 1, 1, main.b);
#elif ALPHAMAP_A_MainTex
				main = half4(1, 1, 1, main.a);
#endif

				half4 detail = GetSphereDetailMap(_DetailTex, IN.detailPos, _DetailScale);

				float viewDist = distance(IN.worldPos.xyz,_WorldSpaceCameraPos);
				half detailLevel = saturate(2 * _DetailDist*viewDist);
				fixed4 color = _Color * main.rgba * lerp(detail.rgba, 1, detailLevel);

				color.rgb = saturate(color.rgb * (1- color.a));
				color.rgb = lerp(1, color.rgb, _ShadowFactor*color.a);
				return lerp(1, color, shadowCheck);
			}

			ENDCG
		}
	}
}