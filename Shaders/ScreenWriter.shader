HEADER
{
    Description = "Framebuffer copy passthrough shader";
}

MODES
{
    Default();
    VrForward();
}

FEATURES
{
}

COMMON
{
    #include "postprocess/shared.hlsl"
}

struct VertexInput
{
    float3 vPositionOs : POSITION < Semantic( PosXyz ); >;
    float2 vTexCoord : TEXCOORD0 < Semantic( LowPrecisionUv ); >;
};

struct PixelInput
{
    float4 vPositionPs : SV_Position;
    float2 vTexCoord : TEXCOORD0;
    #if ( PROGRAM == VFX_PROGRAM_PS )
        float4 vPositionSs : SV_ScreenPosition;
    #endif
};

VS
{
    PixelInput MainVs( VertexInput i )
    {
        PixelInput o;
        o.vPositionPs = float4(i.vPositionOs.xyz, 1.0f);
        o.vTexCoord = i.vTexCoord;
        return o;
    }
}

PS
{
    #include "postprocess/common.hlsl"

    RenderState( DepthWriteEnable, false );
    RenderState( DepthEnable, false );
    RenderState( DepthFunc, ALWAYS );

	RenderState( BlendEnable, true );
	RenderState( SrcBlend, SRC_ALPHA );
	RenderState( DstBlend, INV_SRC_ALPHA );

	//RenderState( SrgbWriteEnable0, true );
	//RenderState( ColorWriteEnable0, RGBA );
	//RenderState( FillMode, SOLID );
	//RenderState( CullMode, NONE );
    
    CreateTexture2D( g_tColorBuffer ) < Attribute( "ColorBuffer" );  	SrgbRead( true ); Filter( MIN_MAG_MIP_POINT ); AddressU( CLAMP ); AddressV( CLAMP ); >;
    CreateTexture2D( g_tMaskBuffer ) < Attribute( "MaskBuffer" );  	SrgbRead( false ); Filter( MIN_MAG_MIP_POINT ); AddressU( CLAMP ); AddressV( CLAMP ); >;
    CreateTexture2D( g_tColorScreenBuffer ) < Attribute( "screen" );  	SrgbRead( true ); Filter( MIN_MAG_MIP_POINT ); AddressU( CLAMP ); AddressV( CLAMP ); >;

	float3 GaussianBlurEx( float3 vColor, float2 vTexCoords )
    {
        float flRemappedBlurSize = 0.5f;

        float fl2PI = 6.28318530718f;
        float flDirections = 16.0f;
        float flQuality = 4.0f;
        float flTaps = 1.0f;

        [unroll]
        for( float d=0.0; d<fl2PI; d+=fl2PI/flDirections)
        {
            [unroll]
            for(float j=1.0/flQuality; j<=1.0; j+=1.0/flQuality)
            {
                flTaps += 1;
                vColor += Tex2D(g_tColorBuffer, vTexCoords + float2( cos(d), sin(d) ) * lerp(0.0f, 0.02, flRemappedBlurSize) * j );    
            }
        }
        return vColor / flTaps;
    }
    float3 GaussianBlurExMask( float3 vColor, float2 vTexCoords )
    {
        float flRemappedBlurSize = 1;

        float fl2PI = 6.28318530718f;
        float flDirections = 16.0f;
        float flQuality = 4.0f;
        float flTaps = 1.0f;

        [unroll]
        for( float d=0.0; d<fl2PI; d+=fl2PI/flDirections)
        {
            [unroll]
            for(float j=1.0/flQuality; j<=1.0; j+=1.0/flQuality)
            {
                flTaps += 1;
                vColor += Tex2D(g_tMaskBuffer, vTexCoords + float2( cos(d), sin(d) ) * lerp(0.0f, 0.02, flRemappedBlurSize) * j ).a;    
            }
        }
        vColor = vColor / flTaps;
        return vColor;
    }

    float4 AdditiveDoBlur( float4 color, float2 uv, float2 size ) 
	{
		float Pi = M_PI * 2;
		float Directions = 16.0; // BLUR DIRECTIONS (Default 16.0 - More is better but slower)
		float Quality = 4.0; // BLUR QUALITY (Default 4.0 - More is better but slower)
	
		// Blur calculations
		for( float d=0.0; d<Pi; d+=Pi/Directions)
		{
			for(float j=1.0/Quality; j<=1.0; j+=1.0/Quality)
			{
				color += Tex2D(g_tColorBuffer, uv + float2( cos(d), sin(d) ) * size * j );	
			}
		}
		
		// Output to screen
		color /= Quality * Directions - 15.0;

		return color;
	}

    float BlurAmount<Default(0.01);Attribute("bluramount");>;

    float4 MainPs( PixelInput i ) : SV_Target0
    {
        float4 color = Tex2D( g_tColorScreenBuffer, i.vTexCoord );
        float mask = Tex2D( g_tMaskBuffer, i.vTexCoord ).a;
        float4 volumetric = Tex2D( g_tColorBuffer, i.vTexCoord );

        float4 preblur = volumetric;

        if(BlurAmount > 0){
            volumetric.rgb = pow(GaussianBlurEx( volumetric, i.vTexCoord),0.80f);
            //volumetric.rgb = pow(AdditiveDoBlur( volumetric, i.vTexCoord, float2(BlurAmount, BlurAmount)),0.9f);
            mask = GaussianBlurExMask( mask.rrr, i.vTexCoord).r;
        }
        float3 blendedColor = lerp(color.rgb, volumetric.rgb,(mask));
        //if(volumetric.r < 0.1f && volumetric.g < 0.1f && volumetric.b < 0.1f) blendedColor = volumetric.rgb;

        return float4( blendedColor.rgb, 1.0f );
        
    }
}