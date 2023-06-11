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
	RenderState( DepthEnable, false );
	RenderState( DepthFunc, LESS_EQUAL );

	RenderState( BlendEnable, true );
	RenderState( SrcBlend, SRC_ALPHA );
	RenderState( DstBlend, INV_SRC_ALPHA );

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

	float g_flStepSize < Default( 8.0f ); Range(1.0f, 256.0f); UiGroup( "Cloud,10/4" ); >;
	float g_flSearchStepSize < Default( 8.0f ); Range(1.0f, 256.0f); UiGroup( "Cloud,10/4" ); >;
	int g_nInitialStepCount < Default( 8 ); Range(1, 256); UiGroup( "Cloud,10/5" ); >;
	int g_nMaxStepCount < Default( 28 ); Range(1, 256); UiGroup( "Cloud,10/6" ); >;

	float g_flVolumeDensity < Default( 1.0f ); Range(0.0f, 1.0f); UiGroup( "Cloud,10/11" ); >;
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


	CreateTexture2D( g_tDepthBufferCopyTexture )   < Attribute( "DepthBuffer" ); SrgbRead( false ); Filter( POINT ); AddressU( MIRROR ); AddressV( MIRROR ); >;

	static float MAX_MARCHING_STEPS = 255;
	static float MIN_DIST =0.0f;
	static float MAX_DIST = 1000.0f;
	static float EPSILON = 0.0001f;


	float SampleDensity( float3 vPosWs )
	{
		vPosWs += g_vWorldPosition;
		//offset position by noise
		vPosWs += float3(
			snoise(((vPosWs+5)/g_flPositionNoiseSize) + g_flTime*g_flPositionNoiseSpeed),
			snoise(((vPosWs+1100)/g_flPositionNoiseSize) + g_flTime*g_flPositionNoiseSpeed),
			snoise(((vPosWs-500)/g_flPositionNoiseSize) + g_flTime*g_flPositionNoiseSpeed))*g_flPositionNoiseStrenght;
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
					
			res = max( res, ((pow(1- sdCapsule( p, -fLength, fLength, fRadius ),0.5f ))*shapePropertiess[i].flPower) );
		}
		// Then boxes
		for ( i = nBoxesStart; i < nCylinderStart; i++ )
		{
			float3 p = mul( float4(vPosWs.xyz,1.0f),shapePropertiess[i].matWorldToProxy ).xyz;
			res = max( res,((pow(1- sdBox( p, shapePropertiess[i].vProxyScale ),0.5f ))*shapePropertiess[i].flPower));
		}
		// Then Cylinder
		for ( i = nCylinderStart; i < nCylinderEnd; i++ )
		{
			float3 p = mul( float4( vPosWs.xyz, 1.0 ), shapePropertiess[i].matWorldToProxy ).zxy;
			res = max( res,((pow(1-  sdCylinder( p,  shapePropertiess[i].vProxyScale.y,  shapePropertiess[i].vProxyScale.x ),0.5f ))*shapePropertiess[i].flPower) );
		}

		float snose = snoise((vPosWs/g_flNoiseSize) + g_flTime*g_flNoiseSpeed);
		res = min(res,(snose*0.5f + 0.5f)*g_flNoiseStrenght);

		// do the subtraction sdfs now
		//Ellipses first
		for ( i = 0; i < nSubBoxesStart; i++ )
		{
			const float fRadius = shapeSubPropertiess[i].vProxyScale.y;
			const float3 fLength = float3( shapeSubPropertiess[i].vProxyScale.x,0,0);
			float3 p = mul( float4( vPosWs.xyz, 1.0 ), shapeSubPropertiess[i].matWorldToProxy ).xyz;
					
			res = min( res, ((pow(1- sdCapsule( p, -fLength, fLength, fRadius ),0.5f ))*shapeSubPropertiess[i].flPower) );
		}
		// Then boxes
		for ( i = nSubBoxesStart; i < nSubCylinderStart; i++ )
		{
			float3 p = mul( float4(vPosWs.xyz,1.0f),shapeSubPropertiess[i].matWorldToProxy ).xyz;
			res = min( res,((pow(1- sdBox( p, shapeSubPropertiess[i].vProxyScale ),0.5f ))*shapeSubPropertiess[i].flPower));
		}
		// Then Cylinder
		for ( i = nSubCylinderStart; i < nSubCylinderEnd; i++ )
		{
			float3 p = mul( float4( vPosWs.xyz, 1.0 ), shapeSubPropertiess[i].matWorldToProxy ).zxy;
			res = min( res,((pow(1-  sdCylinder( p,  shapeSubPropertiess[i].vProxyScale.y,  shapeSubPropertiess[i].vProxyScale.x ),0.5f ))*shapeSubPropertiess[i].flPower) );
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



	float3 Direct( PixelInput i,Material m, float3 LightPos,float3 FragDir,float raydepth)
	{
		float3 FinalColor = float3(0,0,0);
		m.Normal = normalize(FragDir);

		const float shadowCutoffThreshold = -log(SHADOW_CUTOFF) / g_flShadowDensity;


		float3 lightcolorcumm = float3(0.0, 0.0, 0.0);
		float shadowcumm = 0;
		float3 startlightpos = LightPos;

		float3 positionwithoffset = startlightpos-g_vHighPrecisionLightingOffsetWs.xyz;
		uint index;
		[loop]
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
		float3 WorldSpace = i.vPositionWithOffsetWs.xyz + g_vHighPrecisionLightingOffsetWs;
		i.vPositionWithOffsetWs =startlightpos - g_vHighPrecisionLightingOffsetWs.xyz;
		Light lll = AmbientLight::From( i, m );
		FinalColor += lll.Color ;
		//shadow = 0;


		//FinalColor += g_vSunLightColor.rgb*normalize(g_vSunLightDir.xyz);

		float4 color = DoAtmospherics( i, float4(FinalColor,1) );
		color = DoToolVisualizations( i, m, color );
		color = DoPostProcessing( i, m, color );
		return color.rgb;
	}

	//
	// Main
	//
	float4 MainPs( PixelInput i ) : SV_Target0
	{
		float3 vPositionWs = i.vPositionWithOffsetWs.xyz  + g_vHighPrecisionLightingOffsetWs.xyz;

		float3 vRayOrigin =vPositionWs /* -g_vWorldPosition */;
		float3 vRayDir = normalize(   vRayOrigin - (g_vCameraPositionWs /* - g_vWorldPosition */));

		Material m = Material::From( i );

		//return float4(saturate(vRayDir),1);

		float2 vScreenPos = CalculateViewportUv( i.vPositionSs.xy) ;

		float3 vRaySearchDir = vRayDir;
		/* float test = shortestDistanceToSurface(vRayOrigin,vRayDir,MIN_DIST,MAX_DIST);
		if(test > MAX_DIST - EPSILON){
			return float4(0,0,0,1);
		}else{
			return float4(1,0,0,1);
		} */

		float3 luminance = float3(0,0,0);
		float transmittance = 1.0f;

		vRayDir *= g_flStepSize;
		vRaySearchDir *= g_flSearchStepSize;

		float searchSample =SampleDensity(vRayOrigin);
		[loop]
		for(int j = 0; j < g_nInitialStepCount; j++)
		{
			if(searchSample > 0.01)
				break;

			vRayOrigin += vRaySearchDir;
			searchSample =SampleDensity(vRayOrigin);
		}

		if(searchSample < 0.01)
			return float4(0,0,0,0);

		vRayOrigin -= vRaySearchDir;

		float3 vRayCurrentPos = vRayOrigin;

		float depthcutoff = GetDepth( vScreenPos );


		const float shadowCutoffThreshold = -log(SHADOW_CUTOFF) / g_flShadowDensity;

		[loop]
		for(int step = 0; step < g_nMaxStepCount; step++)
		{
			float fDepth = GetDepth( vScreenPos );

			float4 vPosPs = Position3WsToPs( vRayCurrentPos );
			float fDepthObj = vPosPs.z / vPosPs.w;

			float flZScale = g_vInvProjRow3.z;
			float flZTran = g_vInvProjRow3.w;
			float flDepthRelativeToRayLength = 1.0 / ( ( fDepthObj * flZScale + flZTran ) );
			if(fDepth < flDepthRelativeToRayLength){
				break;
			}
			float currentsample = SampleDensity(vRayCurrentPos);

			if(currentsample > 0.001)
			{
			

				float3 lightPos = vRayCurrentPos;
				

				float density = saturate(currentsample * g_flVolumeDensity);

				transmittance *= 1.0 - density;
				luminance = Direct(i,m,lightPos,vRayDir,length(lightPos - vRayOrigin));


				if(transmittance < 0.01)
					break;
			}
			vRayCurrentPos += vRayDir;
		}

		luminance *= g_vExtinctionColor;

		return float4(luminance.xyz,(1-transmittance));
	}
}
