using System;

namespace Sandbox.Systems.Smoke;

public class RenderHookSmoke : RenderHook
{
	public static SceneWorld SmokeWorld { get; set; } = new();
	public override void OnStage( SceneCamera target, Stage renderStage )
	{

		if ( renderStage != Stage.BeforePostProcess ) return;
		Graphics.Clear( true, false );
		var ents = Entity.All.OfType<SmokeInstance>();

		foreach ( var smoke in ents.OrderByDescending( x => x.Position.Distance( target.Position ) ) )
		{
			Graphics.GrabDepthTexture( "DepthBuffer", smoke.so.Attributes );
			Graphics.SetupLighting( smoke.so, smoke.so.Attributes );
			smoke.SetGraphicsParameters();
			smoke.so.RenderSceneObject();
			//Graphics.Render( smoke.so, smoke.Transform );
		}
	}

	public override void OnFrame( SceneCamera target )
	{
		base.OnFrame( target );

		foreach ( var smoke in Entity.All.OfType<SmokeInstance>() )
		{
			smoke.OnRender( target.World );
		}
	}

}

[SceneCamera.AutomaticRenderHook]
public class RenderhookWorldSmoke : RenderHook
{
	public SceneCamera sCamera { get; set; }

	public SceneSunLight SunLight { get; set; }

	public RenderhookWorldSmoke()
	{
		sCamera = new();
		sCamera.AddHook( new RenderHookSmoke() );
		sCamera.World = new();

		sCamera.Worlds.Add( Game.SceneWorld );


	}

	public override void OnFrame( SceneCamera target )
	{
		base.OnFrame( target );
		sCamera.Position = target.Position;
		sCamera.Rotation = target.Rotation;
		sCamera.ZNear = target.ZNear;
		sCamera.ZFar = target.ZFar;
		sCamera.FieldOfView = target.FieldOfView;

	}
	public override void OnStage( SceneCamera target, Stage renderStage )
	{

		if ( renderStage != Stage.BeforePostProcess ) return;

		using var rt = RenderTarget.GetTemporary( 6 );

		Graphics.RenderToTexture( sCamera, rt.ColorTarget );

		RenderAttributes rts = new();
		rts.Set( "ColorBuffer", rt.ColorTarget );
		Graphics.Blit( Material.FromShader( "shaders/screenwriter.shader" ), rts );



	}
}

