using System;

namespace Sandbox.Systems.Smoke;

public class SmokeRenderObject : SceneCustomObject
{
	public SmokeInstance SmokeParent;

	public static Material SmokeMaterial => Material.Load( "shaders/sdfsmoke.vmat" );

	public VertexBuffer vb;

	public SmokeRenderObject( SceneWorld sceneWorld, SmokeInstance parent ) : base( Game.SceneWorld )
	{
		SmokeParent = parent;
		//Update();
		RenderLayer = SceneRenderLayer.OverlayWithoutDepth;
		RenderingEnabled = true;
		Tags.Add( "smoke" );
	}

	public virtual void Update( SceneCamera Target, bool depthpass = false )
	{
		if ( vb == null )
		{
			vb = new VertexBuffer();
			vb.Init( true );
		}
		vb.Clear();
		if ( SmokeParent == null )
		{
			Bounds = new BBox( -100, 100 ) + Target.Position;
			Position = Target.Position;
			vb.AddCube( Target.Position, -10f, Target.Rotation );
			return;
		}
		Position = SmokeParent.Position;
		Bounds = SmokeParent.SmokeSDFBounds;

		//make a cube with the bounds
		if ( Bounds.Contains( Target.Position ) )
		{
			vb.AddCube( Target.Position, -10f, Target.Rotation );
		}
		else
		{
			vb.AddCube( SmokeParent.SmokeSDFBounds.Center, SmokeParent.SmokeSDFBounds.Size, Rotation );
		}

	}

	public override void RenderSceneObject()
	{
		vb.Draw( SmokeMaterial, Attributes );
	}
}

