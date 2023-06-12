//=========================================================================================================================
// Optional
//=========================================================================================================================
HEADER
{
	Description = "Template Shader for S&box";
}

//=========================================================================================================================
// Optional
//=========================================================================================================================
FEATURES
{
	#include "common/features.hlsl"
}

//=========================================================================================================================
COMMON
{
	#include "common/shared.hlsl"
	DynamicCombo( D_BAKED_LIGHTING_FROM_PROBE, 0..1, Sys( ALL ) );
}

//=========================================================================================================================

struct VertexInput
{
	#include "common/vertexinput.hlsl"
};

//=========================================================================================================================

struct PixelInput
{
	#include "common/pixelinput.hlsl"
};

//=========================================================================================================================

VS
{
	#include "common/vertex.hlsl"
	//
	// Main
	//
	PixelInput MainVs( INSTANCED_SHADER_PARAMS( VertexInput i ) )
	{
		PixelInput o = ProcessVertex( i );
		// Add your vertex manipulation functions here
		return FinalizeVertex( o );
	}
}

//=========================================================================================================================

PS
{
	#include "common/pixel.hlsl"

	#include "raytracing/sdf.hlsl"
	#include "SimplexNoise3D.hlsl"


	RenderState( DepthWriteEnable, false );
	RenderState( AlphaToCoverageEnable, false );
	RenderState( DepthEnable, false );
	RenderState( DepthFunc, LESS_EQUAL );

	RenderState( BlendEnable, true );
	RenderState( SrcBlend, SRC_ALPHA );
	RenderState( DstBlend, INV_SRC_ALPHA );


	RenderState( SrcBlend, SRC_ALPHA );
	RenderState( DstBlend, INV_SRC_ALPHA );
	RenderState( BlendOpAlpha, ADD );


	DynamicCombo(D_DEPTHPASS,0..2,Sys(ALL));

	struct ShapeProperties_ts
	{
		float4x4 matWorldToProxy;
		float3 vProxyScale;
		float flPower;
	};

	struct ShapeInstance_ts
	{
		int nStartEllipsoid;
		int nEndEllipsoid;
		int nEndBox;
		int nEndCylinder;
	};

	cbuffer ShapeInstancesConstantbuffer
	{
		ShapeInstance_ts shapeInstances;
	};

	cbuffer subtractionInstancesConstantbuffer{
		ShapeInstance_ts subtractionshapeInstances;
	};

	#define SHAPE_MAX_SHAPESs 110
	cbuffer ShapeConstantBuffer_tss
	{
		ShapeProperties_ts shapePropertiess[SHAPE_MAX_SHAPESs];
	};

	cbuffer subtractionConstantbuffer_tss{
		ShapeProperties_ts shapeSubPropertiess[SHAPE_MAX_SHAPESs];
	};

	float g_flStepSize < Default( 8.0f ); Range(0.1f, 256.0f); UiGroup( "Cloud,10/4" ); >;
	float g_flInitialStepSize < Default( 8.0f ); Range(0.1f, 256.0f); UiGroup( "Cloud,10/4" ); >;
	float g_flSearchStepSize < Default( 8.0f ); Range(0.1f, 256.0f); UiGroup( "Cloud,10/4" ); >;
	int g_nInitialStepCount < Default( 8 ); Range(1, 256); UiGroup( "Cloud,10/5" ); >;
	int g_nSearchStepCount < Default( 8 ); Range(1, 256); UiGroup( "Cloud,10/5" ); >;
	int g_nMaxStepCount < Default( 28 ); Range(1, 256); UiGroup( "Cloud,10/6" ); >;

	float g_flVolumeDensity < Default( 1.0f ); Range(0.0f, 10.0f); UiGroup( "Cloud,10/11" ); >;
	float g_flShadowDensity < Default( 0.1f ); Range(0.0f, 2.0f); UiGroup( "Cloud,10/12" ); >;
	float g_flNoiseStrenght < Default( 0.1f ); Range(0.0f, 20.0f); UiGroup( "Cloud,10/12" ); >;

	float g_flNoiseSize < Default( 30.0f ); Range(0.0f, 100.0f); UiGroup( "Cloud,10/12" ); >;
	float g_flNoiseSpeed < Default( 0.5f ); Range(0.0f, 20.0f); UiGroup( "Cloud,10/12" ); >;

	float g_flPositionNoiseSize < Default( 30.0f ); Range(0.0f, 100.0f); UiGroup( "Cloud,10/12" ); >;
	float g_flPositionNoiseSpeed < Default( 0.5f ); Range(0.0f, 20.0f); UiGroup( "Cloud,10/12" ); >;
	float g_flPositionNoiseStrenght < Default( 0.5f ); Range(0.0f, 20.0f); UiGroup( "Cloud,10/12" ); >;

	int g_nMaxLightSteps < Default( 8 ); Range(1, 16); UiGroup( "Cloud,10/9" ); >;
	float g_flLightStepSize < Default( 4.0f ); Range(0.1f, 128.0f); UiGroup( "Cloud,10/10" ); >;

	
	float3 g_vExtinctionColor < Default3( 1.0f, 1.0f, 1.0f ); UiType( Color ); UiGroup( "Cloud,10/17" ); >;
	float3 g_vWorldPosition<Attribute("WorldPosition");>;

	
	static const float SHADOW_CUTOFF = 0.001;

	int g_nRenderBufferSize<Default(1);Attribute("RenderBufferFactor");>;


	CreateTexture2D( g_tDepthBufferCopyTexture )   < Attribute( "DepthBuffer" ); SrgbRead( false ); Filter( MIN_MAG_MIP_POINT ); AddressU( MIRROR ); AddressV( MIRROR ); >;
	CreateTexture2D( g_tOwnDepthBufferCopyTexture )   < Attribute( "PersonalBuffer" ); SrgbRead( false ); Filter( MIN_MAG_MIP_POINT ); AddressU( MIRROR ); AddressV( MIRROR ); >;

	static float MAX_MARCHING_STEPS = 255;
	static float MIN_DIST =0.0f;
	static float MAX_DIST = 1000.0f;
	static float EPSILON = 0.0001f;


	float SampleDensity( float3 vPosWs )
	{
		//offset position by noise
		float3 offset = float3(
			snoise(((vPosWs+5)/g_flPositionNoiseSize) + g_flTime*g_flPositionNoiseSpeed),
			snoise(((vPosWs+1100)/g_flPositionNoiseSize) + g_flTime*g_flPositionNoiseSpeed),
			snoise(((vPosWs-500)/g_flPositionNoiseSize) + g_flTime*g_flPositionNoiseSpeed))*g_flPositionNoiseStrenght;
		vPosWs += g_vWorldPosition;
		uint nEllipsesStart = shapeInstances.nStartEllipsoid;
		uint nBoxesStart = shapeInstances.nEndEllipsoid;
		uint nCylinderStart = shapeInstances.nEndBox;
		uint nCylinderEnd = shapeInstances.nEndCylinder;

		uint nSubEllipsesStart = subtractionshapeInstances.nStartEllipsoid;
		uint nSubBoxesStart = subtractionshapeInstances.nEndEllipsoid;
		uint nSubCylinderStart = subtractionshapeInstances.nEndBox;
		uint nSubCylinderEnd = subtractionshapeInstances.nEndCylinder;

		/* float res = 0;
		// Then boxes
		for ( uint i = 0; i < 3; i++ )
		{
			float3 p = mul( float4(vPosWs.xyz,1.0f),shapePropertiess[i].matWorldToProxy ).xyz;
			res = max( res,((pow(1- sdBox( p, shapePropertiess[i].vProxyScale ),0.5f ))*shapePropertiess[i].flPower));
		} */

		float res =0;
		
		
		//Ellipses first
		for ( uint i = 0; i < nBoxesStart; i++ )
		{
			const float fRadius = shapePropertiess[i].vProxyScale.y;
			const float3 fLength = float3( shapePropertiess[i].vProxyScale.x,0,0);
			float3 p = mul( float4( vPosWs.xyz, 1.0 ), shapePropertiess[i].matWorldToProxy ).xyz;
			p += offset;
			float resultshape = (1- sdCapsule( p, -fLength, fLength, fRadius )) ;
			if(resultshape > 0)
			{
				//#if D_DEPTHPASS ==2
					resultshape = min(resultshape,pow((snoise((p/g_flNoiseSize) + g_flTime*g_flNoiseSpeed)*0.5f + 0.5f),g_flNoiseStrenght))*shapePropertiess[i].flPower;
				//#endif // D_DEPTHPASS
				res = max( res, resultshape)*shapePropertiess[i].flPower;
			}
			//res = max( res, )*shapePropertiess[i].flPower;
		}
		// Then boxes
		for ( i = nBoxesStart; i < nCylinderStart; i++ )
		{
			float3 p = mul( float4(vPosWs.xyz,1.0f),shapePropertiess[i].matWorldToProxy ).xyz;
			p += offset;
			float resultshape =  (1- sdBox( p, shapePropertiess[i].vProxyScale ));
			if(resultshape > 0)
			{
				//#if D_DEPTHPASS ==2
					resultshape = min(resultshape,pow((snoise((p/g_flNoiseSize) + g_flTime*g_flNoiseSpeed)*0.5f + 0.5f),g_flNoiseStrenght))*shapePropertiess[i].flPower;
				//#endif // D_DEPTHPASS
				res = max( res, resultshape)*shapePropertiess[i].flPower;
			}
		}
		// Then Cylinder
		for ( i = nCylinderStart; i < nCylinderEnd; i++ )
		{
			float3 p = mul( float4( vPosWs.xyz, 1.0 ), shapePropertiess[i].matWorldToProxy ).zxy;
			p += offset;
			float resultshape = (1- sdCylinder( p,  shapePropertiess[i].vProxyScale.y,  shapePropertiess[i].vProxyScale.x )) ;
			if(resultshape > 0)
			{
				//#if D_DEPTHPASS ==2
					resultshape = min(resultshape,pow((snoise((p/g_flNoiseSize) + g_flTime*g_flNoiseSpeed)*0.5f + 0.5f),g_flNoiseStrenght))*shapePropertiess[i].flPower;
				//#endif // D_DEPTHPASS
				res = max( res, resultshape)*shapePropertiess[i].flPower;
				
			}
		}


		res = min(res,pow((snoise(((vPosWs-g_vWorldPosition)/g_flNoiseSize) + g_flTime*g_flNoiseSpeed)*0.5f + 0.5f),g_flNoiseStrenght));

		// do the subtraction sdfs now
		//Ellipses first
		for ( i = 0; i < nSubBoxesStart; i++ )
		{
			const float fRadius = shapeSubPropertiess[i].vProxyScale.y;
			const float3 fLength = float3( shapeSubPropertiess[i].vProxyScale.x,0,0);
			float3 p = mul( float4( vPosWs.xyz, 1.0 ), shapeSubPropertiess[i].matWorldToProxy ).xyz;
					
			p += offset;
			float resultshape = ( sdCapsule( p, -fLength, fLength, fRadius )) ;
			if(resultshape < 0)
			{
				res = min( res, resultshape);
			}
		}
		// Then boxes
		for ( i = nSubBoxesStart; i < nSubCylinderStart; i++ )
		{
			float3 p = mul( float4(vPosWs.xyz,1.0f),shapeSubPropertiess[i].matWorldToProxy ).xyz;
			p += offset;
			float resultshape =  ( sdBox( p, shapePropertiess[i].vProxyScale ));
			if(resultshape < 0)
			{
				res = min( res, resultshape);
			}
		}
		// Then Cylinder
		for ( i = nSubCylinderStart; i < nSubCylinderEnd; i++ )
		{
			float3 p = mul( float4( vPosWs.xyz, 1.0 ), shapeSubPropertiess[i].matWorldToProxy ).zxy;
			p += offset;
			float resultshape = ( sdCylinder( p,  shapePropertiess[i].vProxyScale.y,  shapePropertiess[i].vProxyScale.x )) ;
			if(resultshape < 0)
			{
				res = min( res, resultshape);
				
			}
		}

		


		
		return res;
	}

	float GetDepth( float2 vTexCoord )
	{
		float flProjectedDepth = Tex2D( g_tDepthBufferCopyTexture, vTexCoord.xy ).x;
		flProjectedDepth = RemapValClamped( flProjectedDepth,g_flViewportMinZ, g_flViewportMaxZ, 0, 1);

		float flZScale = g_vInvProjRow3.z;
		float flZTran = g_vInvProjRow3.w;

		float flDepthRelativeToRayLength = 1.0 / ( ( flProjectedDepth * flZScale + flZTran ) );

		return flDepthRelativeToRayLength;
	}

	float GetOwnDepth( float2 vTexCoord )
	{
		float flProjectedDepth = Tex2D( g_tOwnDepthBufferCopyTexture, vTexCoord.xy ).x;
		flProjectedDepth = RemapValClamped( flProjectedDepth,g_flViewportMinZ, g_flViewportMaxZ, 0, 1);

		float flZScale = g_vInvProjRow3.z;
		float flZTran = g_vInvProjRow3.w;

		float flDepthRelativeToRayLength = 1.0 / ( ( flProjectedDepth * flZScale + flZTran ) );

		return flDepthRelativeToRayLength;
	}



	float3 Direct( PixelInput i,Material m, float3 LightPos,float3 FragDir,float3 raydepth)
	{
		float3 FinalColor = float3(0,0,0);
		m.Normal = normalize(FragDir);

		const float shadowCutoffThreshold = -log(SHADOW_CUTOFF) / g_flShadowDensity;


		float3 lightcolorcumm = float3(0.0, 0.0, 0.0);
		float shadowcumm = 0;
		float3 startlightpos = LightPos;

		float3 positionwithoffset = startlightpos-g_vHighPrecisionLightingOffsetWs.xyz;
		uint index;
		/* [loop]
		for ( index = 0; index < DynamicLight::Count( i ); index++ )
		{
			[loop]
			for(int lightss = 0; lightss < g_nMaxLightSteps; lightss++)
			{
				i.vPositionWithOffsetWs =startlightpos - g_vHighPrecisionLightingOffsetWs.xyz;
				Light light = DynamicLight::From( i, index );
				//if( light.Visibility > 0.0f )
				//	vLightResult = LightResult::Sum( vLightResult, Direct( input, light ) );
				startlightpos += (light.Direction)*g_flLightStepSize;
				shadowcumm += SampleDensity(startlightpos);
				
				lightcolorcumm += saturate(light.Color*light.Attenuation*light.Visibility )/g_nMaxLightSteps;
				if(shadowcumm > shadowCutoffThreshold)
					break;
				
			}
		startlightpos = LightPos;

		}

		[loop]
		for ( index = 0; index < StaticLight::Count( i ); index++ )
		{
			[loop]
			for(int lightss = 0; lightss < g_nMaxLightSteps; lightss++)
			{
				i.vPositionWithOffsetWs =startlightpos - g_vHighPrecisionLightingOffsetWs.xyz;
				Light light = StaticLight::From( i, index );
				if( light.Visibility > 0.0f ){
					//	vLightResult = LightResult::Sum( vLightResult, Direct( input, light ) );
					startlightpos += (light.Direction)*g_flLightStepSize;
					shadowcumm += SampleDensity(startlightpos);

					lightcolorcumm += saturate(light.Color*light.Attenuation*light.Visibility )/g_nMaxLightSteps;
					if(shadowcumm > shadowCutoffThreshold)
						break;
				}
					
			}
				
		startlightpos = LightPos;
			
		}
 
		startlightpos = LightPos;
		FinalColor += lightcolorcumm / index;
		lightcolorcumm = float3(0.0, 0.0, 0.0);
		shadowcumm = 0;
		*/
		float3 vAmbientCube[6];
		SampleLightProbeVolume( vAmbientCube, LightPos );
		FinalColor += SampleIrradiance( vAmbientCube,-m.Normal ).xyz;
		//shadow = 0;


		//FinalColor += g_vSunLightColor.rgb*normalize(g_vSunLightDir.xyz);

		//float4 color = DoAtmospherics( i, float4(FinalColor,1) );
		//color = DoToolVisualizations( i, m, color );
		//color = DoPostProcessing( i, m, color );
		return FinalColor.rgb;
	}

	//
	// Main
	//
	float4 MainPs( PixelInput i ) : SV_Target0
	{
		float3 vPositionWs = i.vPositionWithOffsetWs.xyz  + g_vHighPrecisionLightingOffsetWs.xyz;

		float3 vRayOrigin =vPositionWs /* -g_vWorldPosition */;
		float3 vRayDir = normalize(   vRayOrigin - g_vCameraPositionWs );
		float2 vOwnScreenPos =  CalculateViewportUv((( i.vPositionSs.xy*g_nRenderBufferSize))/* / g_vRenderTargetSize */ );

		#if D_DEPTHPASS <= 0
			return float4(1,1,1,0);
		#endif

		float2 vScreenPos =  CalculateViewportUv((( i.vPositionSs.xy)*g_nRenderBufferSize)/* / g_vRenderTargetSize */ );

		float3 vRaySearchDir = vRayDir;

		float3 luminance = float3(0,0,0);
		float transmittance = 1.0f;

		float depthcutoff = GetOwnDepth( vScreenPos );
		float flworlddepth = GetDepth( vScreenPos );

		vRaySearchDir *= g_flInitialStepSize;
		vRayDir *= g_flStepSize;
		float4 OthersDepth = Tex2D( g_tOwnDepthBufferCopyTexture, vOwnScreenPos.xy );
		#if D_DEPTHPASS == 1
			float searchSample =SampleDensity(vRayOrigin);
			[loop]
			for(int j = 0; j < g_nInitialStepCount; j++)
			{
				if(searchSample > 0.2)
					break;

				vRayOrigin += vRaySearchDir;
				
				searchSample =SampleDensity(vRayOrigin);
			}
			if(searchSample > 0.01){
				float4 vPosPs = Position3WsToPs( vRayOrigin );
				float fDepthObj = vPosPs.z / vPosPs.w;

				float flZScale = g_vInvProjRow3.z;
				float flZTran = g_vInvProjRow3.w;
				float flDepthRelativeToRayLength = 1.0 / ( ( fDepthObj * flZScale + flZTran ) );
				if( flDepthRelativeToRayLength >= flworlddepth )
					discard;
				
				if(distance(vRayOrigin.xyz,g_vCameraPositionWs) <= distance(OthersDepth.xyz,g_vCameraPositionWs))
					return float4(vRayOrigin,1);
				else
					return float4(OthersDepth.xyz,1);
				if(length(OthersDepth) <= 0.01f)
					return float4(vRayOrigin,1);
			}
			return float4(OthersDepth.rgb,0);
			discard;
		#endif
		//return float4(1,1,1,0);
		if(length(OthersDepth.a) <= 0.0001f)
			discard;
		vRayOrigin = (OthersDepth.xyz);
		vRayDir = normalize( vRayOrigin-g_vCameraPositionWs );

		float3 vSearchRayDir =vRayDir* g_flSearchStepSize;
		vRayDir *= g_flStepSize;

		float StartSample =SampleDensity(vRayOrigin);
		[loop]
		for(int search = 0; search < g_nSearchStepCount; search++)
		{
			if(StartSample > 0.001)
				break;
			vRayOrigin += vSearchRayDir;
			StartSample =SampleDensity(vRayOrigin);
			
		}
		if(StartSample < 0.001)
			discard;


		vRayOrigin -= vSearchRayDir;

		float3 vRayCurrentPos = vRayOrigin;
		Material m = Material::From( i );

		//return float4(vRayOrigin,1);
		//#define S_CheapSmoke 1
		#if S_CheapSmoke
			float4 vPosPs = Position3WsToPs( vRayCurrentPos );
			float fDepthObj = vPosPs.z / vPosPs.w;

			float flZScale = g_vInvProjRow3.z;
			float flZTran = g_vInvProjRow3.w;
			float flDepthRelativeToRayLength = 1.0 / ( ( fDepthObj * flZScale + flZTran ) );
			if(flworlddepth < flDepthRelativeToRayLength){
				discard;
			}
			float3 vAmbientCube[6];
			SampleLightProbeVolume( vAmbientCube, vRayOrigin );
			return float4(SampleIrradiance( vAmbientCube,vRaySearchDir ).xyz,1);
		#endif // S_CheapSmoke

		
		


		const float shadowCutoffThreshold = -log(SHADOW_CUTOFF) / g_flShadowDensity;
		[loop]
		for(int step = 0; step < g_nMaxStepCount; step++)
		{
			//float fDepth = GetOwnDepth( vScreenPos );

			float4 vPosPs = Position3WsToPs( vRayCurrentPos );
			float fDepthObj = vPosPs.z / vPosPs.w;

			float flZScale = g_vInvProjRow3.z;
			float flZTran = g_vInvProjRow3.w;
			float flDepthRelativeToRayLength = 1.0 / ( ( fDepthObj * flZScale + flZTran ) );
			if(flworlddepth < flDepthRelativeToRayLength){
				//return float4(1,0,0,1);
				break;
			}
			//else{
			//	return float4(0,1,0,1);
			//}

			float currentsample = SampleDensity(vRayCurrentPos);

			if(currentsample >= 0.001)
			{
				float3 lightPos = vRayCurrentPos;
				float density = saturate(currentsample * g_flVolumeDensity);

				luminance = Direct(i,m,lightPos,vRayDir,OthersDepth);
				//luminance = float3(1,1,1);
				float wouldbetransmittance = transmittance * (1 - (density));
				if(wouldbetransmittance < 0.01){
					transmittance = 0;
					break;
				}
				transmittance =wouldbetransmittance;
			}
			vRayCurrentPos += vRayDir;
		}

		luminance *= g_vExtinctionColor;

		return float4(luminance.xyz,1-transmittance);
	}
}
