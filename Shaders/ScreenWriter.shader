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
    
    CreateTexture2D( g_tColorBuffer ) < Attribute( "ColorBuffer" );  	SrgbRead( true ); Filter( ANISO ); AddressU( CLAMP ); AddressV( CLAMP ); >;

	float4 DoBlur( float4 color, float2 uv, float2 size ) 
	{
		float Pi = M_PI * 2;
		float Directions = 16.0; // BLUR DIRECTIONS (Default 16.0 - More is better but slower)
		float Quality = 4.0; // BLUR QUALITY (Default 4.0 - More is better but slower)
	
		// Blur calculations
		for( float d=0.0; d<Pi; d+=Pi/Directions)
		{
			for(float j=1.0/Quality; j<=1.0; j+=1.0/Quality)
			{
				color += Tex2D( g_tColorBuffer,( uv + float2( cos(d), sin(d) ) * size * j ));	
			}
		}
		
		// Output to screen
		color /= Quality * Directions - 15.0;

		return color;
	}

    float4 MainPs( PixelInput i ) : SV_Target0
    {
		float4 color = DoBlur( Tex2D( g_tColorBuffer, i.vTexCoord ), i.vTexCoord, float2( 0.003, 0.003 ));
		color.a = saturate(pow( color.a, 0.5 ));
		//if( color.a < 0.1 ) discard;
        return color;
    }
}