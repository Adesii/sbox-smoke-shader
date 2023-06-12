using System;

namespace Sandbox.Systems.Smoke;

[SceneCamera.AutomaticRenderHook]
public class RenderhookWorldSmoke : RenderHook
{
	//public SceneCamera sCamera { get; set; }

	//public SceneSunLight SunLight { get; set; }

	SmokeRenderObject ScreenRenderer;

	public RenderhookWorldSmoke()
	{
		//sCamera = new();
		//sCamera.AddHook( new RenderHookSmoke() );
		//sCamera.World = Game.SceneWorld;

		//sCamera.Worlds.Add( Game.SceneWorld );



	}

	public override void OnFrame( SceneCamera target )
	{
		base.OnFrame( target );
		target.ExcludeTags.Add( "smoke" );
	}

	public override void OnStage( SceneCamera target, Stage renderStage )
	{

		if ( renderStage != Stage.BeforePostProcess ) return;

		var ents = Entity.All.OfType<SmokeInstance>();

		if ( ScreenRenderer == null )
		{
			ScreenRenderer = new( new(), null );
		}

		ScreenRenderer.Attributes.Clear();

		//Graphics.RenderToTexture( sCamera, rt.ColorTarget );
		foreach ( var smokes in ents.OrderByDescending( x => x.Position.Distance( target.Position ) ) )
		{
			//Graphics.GrabDepthTexture( "DepthBuffer", smoke.so.Attributes );
			Graphics.SetupLighting( smokes.so, smokes.so.Attributes );
		}
		Graphics.GrabDepthTexture( "DepthBuffer" );

		RenderAttributes screenblit = new();
		int downsampling = 4;
		//using var MaskPass = RenderTarget.GetTemporary( 1/* , msaa: 2 */ );
		using var DepthPass = RenderTarget.GetTemporary( 3/* , msaa: 2 */ );
		using var MainPass = RenderTarget.GetTemporary( downsampling );
		//Graphics.RenderTarget = MainPass;
		//Graphics.Clear();
		var idk = ents.OrderByDescending( x => (x.SmokeSDFBounds + -target.Position).ClosestPoint( target.Position ).Length );
		{
			Graphics.RenderTarget = DepthPass;
			Graphics.Clear( Color.Black.WithAlpha( 0f ), true, true, true );

			foreach ( var idd in idk.Reverse() )
			{
				idd.so.Attributes.Set( "RenderBufferFactor", 3 );
				Graphics.GrabFrameTexture( "PersonalBuffer", idd.so.Attributes );
				SmokeInstance.SetGraphicsParameters( idd.so );
				idd.so.Update( target );
				idd.so.Attributes.SetCombo( "D_DEPTHPASS", 1 );
				idd.so.RenderSceneObject();
				//idd.so.Attributes.SetCombo( "D_DEPTHPASS", 0 );
			}
			//Graphics.GrabFrameTexture( "ColorBuffer", screenblit );
			//Graphics.RenderTarget = MainPass;

			//screenblit.Set( "ColorBuffer", DepthPass.ColorTarget );
			//Graphics.Blit( Material.FromShader( "shaders/screenwriter.shader" ), screenblit );
		}
		/* {
			Graphics.RenderTarget = MaskPass;
			Graphics.Clear();
			foreach ( var idd in idk.Reverse() )
			{
				idd.so.Attributes.Set( "RenderBufferFactor", 1 );
				Graphics.GrabFrameTexture( "PersonalBuffer", idd.so.Attributes );
				SmokeInstance.SetGraphicsParameters( idd.so );
				idd.so.Update( target );
				idd.so.Attributes.SetCombo( "D_DEPTHPASS", 3 );
				idd.so.RenderSceneObject();
				//idd.so.Attributes.SetCombo( "D_DEPTHPASS", 0 );
			}
		} */
		Graphics.RenderTarget = MainPass;
		ScreenRenderer.Attributes.Set( "PersonalBuffer", DepthPass.ColorTarget );
		Graphics.Clear();

		//Graphics.GrabFrameTexture( "PersonalBuffer", smoke.so.Attributes );


		ScreenRenderer.Attributes.Set( "RenderBufferFactor", downsampling );
		ScreenRenderer.Attributes.SetCombo( "D_DEPTHPASS", 2 );
		ScreenRenderer.Update( target, true );
		Graphics.SetupLighting( ScreenRenderer, ScreenRenderer.Attributes );
		Graphics.SetupLighting( ScreenRenderer );
		SmokeInstance.SetGraphicsParameters( ScreenRenderer );
		ScreenRenderer.RenderSceneObject();

		//Graphics.RenderTarget = null;

		//Graphics.GrabFrameTexture( "ColorBuffer", screenblit );
		Graphics.RenderTarget = null;
		screenblit.Clear();
		//screenblit.Set( "bluramount", 0.01f );
		screenblit.Set( "ColorBuffer", MainPass.ColorTarget );
		screenblit.Set( "MaskBuffer", DepthPass.ColorTarget );
		Graphics.GrabFrameTexture( "screen", screenblit );
		//screenblit.Set( "ColorBuffer", DepthPass.ColorTarget );
		Graphics.Blit( Material.FromShader( "shaders/screenwriter.shader" ), screenblit );

		//target.ExcludeTags.Add( "smoke" );

		DepthPass.Dispose();
		MainPass.Dispose();





	}
}

