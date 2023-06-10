using System;

namespace Sandbox.Systems.Smoke;

public class SmokeRenderObject : SceneCustomObject
{
	SmokeInstance SmokeParent;

	public static Material SmokeMaterial => Material.Load( "shaders/sdfsmoke.vmat" );

	VertexBuffer vb;

	public SmokeRenderObject( SceneWorld sceneWorld, SmokeInstance parent ) : base( RenderHookSmoke.SmokeWorld )
	{
		SmokeParent = parent;
		Update();
		RenderLayer = SceneRenderLayer.OverlayWithDepth;
	}

	public virtual void Update()
	{
		Position = SmokeParent.Position;
		Bounds = SmokeParent.SmokeSDFBounds;

		//make a cube with the bounds
		if ( vb == null )
		{
			vb = new VertexBuffer();
			vb.Init( true );
		}
		vb.Clear();
		vb.AddCube( SmokeParent.SmokeSDFBounds.Center, SmokeParent.SmokeSDFBounds.Size, Rotation );
	}

	public override void RenderSceneObject()
	{
		vb.Draw( SmokeMaterial, Attributes );

	}
}

