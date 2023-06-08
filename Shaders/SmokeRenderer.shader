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
	#include "SimplexNoise3D.hlsl"
	#include "atmosphere_sky.fxc"

	//RenderState( CullMode, BACK );
	RenderState( DepthWriteEnable, true );
	RenderState( DepthEnable, false );
	RenderState( DepthFunc, LESS_EQUAL );

	RenderState( BlendEnable, true );
	RenderState( SrcBlend, SRC_ALPHA );
	RenderState( DstBlend, INV_SRC_ALPHA );

	#define S_PER_LIGHT_SAMPLING 1
	//#define MAX_LIGHTS 


	float g_flStepSize < Default( 8.0f ); Range(1.0f, 128.0f); UiGroup( "Cloud,10/4" ); >;
	int g_nInitialStepCount < Default( 8 ); Range(1, 16); UiGroup( "Cloud,10/5" ); >;
	int g_nMaxStepCount < Default( 28 ); Range(1, 64); UiGroup( "Cloud,10/6" ); >;

	float g_flSizeJitterAmount < Default( 1.0f ); Range(0.0f, 2.0f); UiGroup( "Cloud,10/7" ); >;
	float g_flPositionJitterAmount < Default( 0.0f ); Range(0.0f, 2.0f); UiGroup( "Cloud,10/8" ); >;
	int g_nMaxLightSteps < Default( 8 ); Range(1, 16); UiGroup( "Cloud,10/9" ); >;
	float g_flLightStepSize < Default( 4.0f ); Range(0.1f, 128.0f); UiGroup( "Cloud,10/10" ); >;

	float g_flVolumeDensity < Default( 1.0f ); Range(0.0f, 1.0f); UiGroup( "Cloud,10/11" ); >;
	float g_flShadowDensity < Default( 0.1f ); Range(0.0f, 2.0f); UiGroup( "Cloud,10/12" ); >;

	float g_flViewAlignStepSize < Default( 0.25f ); Range(0.0f, 4.0f); UiGroup( "Cloud,10/13" ); >;

	float g_flInitialSearchStepSize < Default( 8.0f ); Range(1.0f, 128.0f); UiGroup( "Cloud,10/14" ); >;
	int g_nInitialSearchSteps < Default( 4 ); Range(1, 16); UiGroup( "Cloud,10/15" ); >;
	float g_flAmbientSampleDistance < Default( 1.0f ); Range(0.0f, 4.0f); UiGroup( "Cloud,10/16" ); >;

	float3 g_vExtinctionColor < Default3( 1.0f, 1.0f, 1.0f ); UiType( Color ); UiGroup( "Cloud,10/17" ); >;

	int g_nNoiseOctaves < Default( 10 ); Range(1, 15); UiGroup( "Cloud,10/18" ); >;
	float g_flNoiseRoughness < Default( 0.7f ); Range(0.0f, 1.0f); UiGroup( "Cloud,10/19" ); >;
	float g_flNoiseCutoff < Default( 0.4f ); Range(0.0f, 1.0f); UiGroup( "Cloud,10/20" ); >;
	float g_flNoiseIntensity < Default( 0.75f ); Range(0.0f, 1.0f); UiGroup( "Cloud,10/21" ); >;

	float g_flCloudScale < Default( 300.0f ); Range(0.0f, 1000.0f); UiGroup( "Cloud,10/22" ); >;
	float g_flCloudVerticalScale < Default( 0.25f ); Range(0.0f, 1.0f); UiGroup( "Cloud,10/23" ); >;

	static const float SHADOW_CUTOFF = 0.001;

	float3 WorldSize<Attribute("WorldSize");>;



	CreateTexture3D( g_CubeTexture) < Attribute( "CubeTexture" );SrgbRead(false);OutputFormat(A8); AddressU(CLAMP);AddressV(CLAMP);AddressW(CLAMP);Filter(BILINEAR); >;
	CreateTexture2D( g_tDepthBufferCopyTexture )   < Attribute( "DepthBuffer" ); SrgbRead( false ); Filter( POINT ); AddressU( MIRROR ); AddressV( MIRROR ); >;

	
	float3 WorldPosition<Attribute("WorldPosition");>;

	
	float SampleDensityTexture(PixelInput i, float3 position )
	{
		float3 vPositionWs = i.vPositionWithOffsetWs.xyz + g_vHighPrecisionLightingOffsetWs.xyz;
		float3 samplepos = (position);
		samplepos = samplepos/(8*8*2);
		if(samplepos.x < 0 || samplepos.x > 1 || samplepos.y < 0 || samplepos.y > 1 || samplepos.z < 0 || samplepos.z > 1)
			return 0;
		float density = Tex3D( g_CubeTexture, samplepos).a;

		float snose = snoise(samplepos*8 + g_flTime*0.5f);
		density *= ((snose+1)/2)+0.2f;
		return density;
	}


	float SampleLightDirect( float3 vPosWs)
	{
		// if CSM
		//{
			//vSample = ComputeSunShadowScalar( vSampleWs );
		//}
		
		//If not CSM
		{
			int4 vLightIndices; 																	// Unused
			float4 vLightScalars; 																	// 3D lightmap for direct light
			SampleLightProbeVolumeIndexedDirectLighting( vLightIndices, vLightScalars, vPosWs ); 	// Sample it

			float fMixedShadows = MixedShadows( vPosWs - g_vHighPrecisionLightingOffsetWs.xyz );

			// I am not 100% sure alpha channel is used for sun in every case for the global sunlight
			return vLightScalars.a * fMixedShadows;
		}
		
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

	float4 GetReprojectedScreenPosition( float3 vPositionWs )
	{
		float4 vPositionPs = Position3WsToPs( vPositionWs );
        vPositionPs.xyz /= vPositionPs.w;
        float2 vPositionSs = PsToSs( vPositionPs );
        vPositionSs.x = 1.0f - vPositionSs.x;

		return Position3WsToPsMultiview(0, vPositionWs );
	}

	float3 CalculateAmbientLightDirectionSmoothed( float3 vPositionWs )
	{
		// This sucks, but deriving directionality from the voxel lighting can get noisy if not compiled with full
		float3 vTotalNormals = 0;

		[unroll]
		for( int x=-1;x<1;x++ )
		{
			[unroll]
			for( int y=-1;y<1;y++ )
			{
				[unroll]
				for( int z=-1;z<1;z++ )
				{
					float3 vNormal = CalculateAmbientLightDirection( vPositionWs + ( ( float3( x , y, z ) + 0.5f ) * 16.0f ) );
					vTotalNormals += vNormal;
				}
			}
		}
		return normalize( vTotalNormals );
	}


	float3 Direct( PixelInput i,Material m, float3 LightPos,float3 FragDir,float raydepth,out float shadow )
	{
		float3 FinalColor = float3(0,0,0);
		m.Normal = normalize(FragDir);

		const float shadowCutoffThreshold = -log(SHADOW_CUTOFF) / g_flShadowDensity;


		float3 lightcolorcumm = float3(0.0, 0.0, 0.0);
		float shadowcumm = 0;
		float3 startlightpos = LightPos;

		float3 positionwithoffset = i.vPositionWithOffsetWs.xyz;
		uint index;
		shadow = 0;
		[loop]
		for ( index = 0; index < DynamicLight::Count( i ); index++ )
		{
			[loop]
			for(int lightss = 0; lightss < g_nMaxLightSteps; lightss++)
			{
				i.vPositionWithOffsetWs =(startlightpos-FragDir)-(g_vCameraPositionWs- WorldPosition);
				Light light = DynamicLight::From( i, index );
				//if( light.Visibility > 0.0f )
				//	vLightResult = LightResult::Sum( vLightResult, Direct( input, light ) );
				startlightpos += (light.Direction)*g_flLightStepSize;
				shadowcumm += SampleDensityTexture(i,startlightpos);
				
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
				i.vPositionWithOffsetWs =(startlightpos-FragDir)-(g_vCameraPositionWs- WorldPosition);
				Light light = StaticLight::From( i, index );
				if( light.Visibility > 0.0f ){
					//	vLightResult = LightResult::Sum( vLightResult, Direct( input, light ) );
					startlightpos += (light.Direction)*g_flLightStepSize;
					shadowcumm += SampleDensityTexture(i,startlightpos);

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
		shadow += shadowcumm / index;
		shadowcumm = 0;
		float3 WorldSpace = i.vPositionWithOffsetWs.xyz + g_vHighPrecisionLightingOffsetWs;
		i.vPositionWithOffsetWs =(startlightpos-FragDir)-(g_vCameraPositionWs- WorldPosition);
		Light lll = AmbientLight::From( i, m );
		FinalColor += lll.Color ;
		//shadow = 0;


		//FinalColor += g_vSunLightColor.rgb*normalize(g_vSunLightDir.xyz);

		float4 color = DoAtmospherics( i, float4(FinalColor,1) );
        color = DoToolVisualizations( i, m, color );
        color = DoPostProcessing( i, m, color );
        return color.rgb;
	}
	void march( PixelInput input,Material m, out float3 luminance, out float transmittance )
	{
		luminance = float3(0.0, 0.0, 0.0);
		transmittance = 1.0;

		float3 vPositionWs = input.vPositionWithOffsetWs.xyz  + g_vHighPrecisionLightingOffsetWs;
		float3 otherfrag = (vPositionWs-WorldPosition);
		
		float3 fragPos = otherfrag;

		float3 fragDir = normalize(otherfrag - (g_vCameraPositionWs-WorldPosition));
		float2 vPositionSs = CalculateViewportUv( input.vPositionSs.xy) ;

		/* luminance =vPositionSs.xyx;
		transmittance = 0;
		return; */
		float2 fragPosSs =vPositionSs;
		
		
		float stepSize = g_flStepSize;
		float searchStepSize = g_flInitialSearchStepSize;
		float3 searchDir = fragDir;

		

		fragDir *= stepSize;
		searchDir *= searchStepSize;

 

		// search to find the start of the volume
		float searchSample = SampleDensityTexture(input,fragPos);
		[loop]
		for( int j = 0; j < g_nInitialStepCount; j++ )
		{
			if(searchSample > 0.01)
				break;
			
			fragPos += searchDir;
			searchSample = SampleDensityTexture(input,fragPos);
		}

		// don't bother marching if we still haven't found anything
		if(searchSample < 0.001)
			return;
			
		
		fragPos -= searchDir;


		float3 curPos = fragPos;

		

		float cutoffDepth = GetDepth(fragPosSs.xy);
		//luminance = cutoffDepth;
		//transmittance = 0;
		//return ;

		float3 shadowDensity = float3(g_flShadowDensity, g_flShadowDensity, g_flShadowDensity);
		shadowDensity /= g_vExtinctionColor;
		
		[loop]
		for (int k = 0; k < g_nMaxStepCount; k++)
		{
			
			if( length( ((curPos)-(g_vCameraPositionWs-WorldPosition))) >= cutoffDepth)
				break;
			
			float curSample = SampleDensityTexture(input,curPos);

			if(curSample > 0.001)
			{
				//march towards the sun
				float3 lightPos = curPos;
				float shadow = 0.0;

				LightResult vLightResult = LightResult::Init();
				//input.vPositionWithOffsetWs = (startlightpos-g_vCameraPositionWs)+WorldPosition;

				float density = saturate(curSample * g_flVolumeDensity);


				// love me some beer's law
				float shadowTerm = exp(-shadow * g_flShadowDensity);
				//float3 shadowTerm = exp(-shadow * shadowDensity);

				float3 absorbedLight = shadowTerm * density ;

				transmittance *= 1.0 - density;
				luminance += absorbedLight * transmittance;
				luminance = Direct(input,m,lightPos,fragDir,length(curPos-fragPos),shadow);

				
				//not much point in sampling after the transmittance gets really low
				if(transmittance < 0.1)
					break;	
				
			}

			curPos += fragDir;
		}
		//float ss;
		//luminance += Direct(input,m,curPos,ss);


		//input.vPositionWithOffsetWs = curPos + WorldPosition;

		//luminance = vLightResult.Diffuse;
	}

	
	//
	// Main
	//
	float4 MainPs( PixelInput i ) : SV_Target0
	{
		//return 1;
		float3 luminance;
		float transmittance;
		march( i,Material::From(i), luminance, transmittance );

		return float4( luminance, saturate(1-transmittance) );
	}


	
}
