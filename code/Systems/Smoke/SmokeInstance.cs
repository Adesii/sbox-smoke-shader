using System;
using System.Collections.Generic;
using System.Numerics;
using Sandbox.Systems.Smoke.SDFS;

namespace Sandbox.Systems.Smoke;

public partial class SmokeInstance : Entity
{

	public static Material smokematerial => Material.Load( "shaders/smoke.vmat" );

	RenderAttributes attributes = new RenderAttributes();

	public BBox SmokeSDFBounds = new BBox( new Vector3( -1, -1, -1 ), new Vector3( 1, 1, 1 ) );

	public List<SmokeSDF> SmokeSDFs = new();


	public override void Spawn()
	{
		base.Spawn();
		Transmit = TransmitType.Always;
	}

	public override void ClientSpawn()
	{
		base.ClientSpawn();
		so = new( new(), this );

		SmokeSDFs.Add( new CapsuleSDF( Position, 5, 20f )
		{
			Rotation = Rotation.FromPitch( 90 )
		} );
		SmokeSDFs.Add( new CylinderSDF( Position, 5, 20f ) );
		SmokeSDFs.Add( new SphereSDF( Position, 10 ) );
		SmokeSDFs.Add( new BoxSDF( Position, 15 ) );


		//SmokeSDFs.Add( new BoxSDF( Position + 10, 10, 0.1f ) );

		//SmokeSDFs.Add( new BoxSDF( Position - 10, 30, 0.5f ) );
		//mokeSDFs.Add( new BoxSDF( Position, new Vector3( 1, 1, 1 ) ) );
		//mokeSDFs.Add( new BoxSDF( Position - 5, new Vector3( 5, 1, 1 ) ) );

		goals.Add( new Transform( Position + 10 ) );
		goals.Add( new Transform( Position - 10 ) );
		goals.Add( new Transform( Position + 1 ) );
	}

	protected override void OnDestroy()
	{
		base.OnDestroy();
		so?.Delete();
	}

	TimeSince LastUpdate;

	[GameEvent.Tick.Server]
	private void Tick()
	{
		Think();

		UpdateAll();
	}
	float dists = 0;
	float Targetdists = 0;

	[ClientRpc]
	private void UpdateAll()
	{
		if ( goals.Count != SmokeSDFs.Count )
		{
			goals.Clear();
			foreach ( var sdf in SmokeSDFs )
			{
				goals.Add( new Transform( sdf.Position ) );
			}
		}
		int i = 0;
		foreach ( var sdf in SmokeSDFs )
		{
			var goal = goals[i];
			sdf.Position = sdf.Position.LerpTo( goal.Position, Time.Delta * 0.5f );
			if ( sdf.Position.Distance( goal.Position ) < 10f )
			{
				goal.Position = (Vector3.Random * 100) + Position;
			}

			sdf.Rotation = Rotation.Slerp( sdf.Rotation, goal.Rotation, Time.Delta );
			if ( sdf.Rotation.Distance( goal.Rotation ) < 40f )
			{
				goal.Rotation = Rotation.Random;
			}

			goals[i] = goal;
			i++;
		}

		//update smokebounds to fit all the sdfs
		SmokeSDFBounds = new BBox( Position, 0 );
		foreach ( var sdf in SmokeSDFs )
		{
			BBox sdfbox = sdf.GetBounds( this );
			SmokeSDFBounds = SmokeSDFBounds.AddBBox( sdfbox );
			//SmokeSDFBounds = SmokeSDFBounds.AddPoint( sdfbox.Maxs );
			//DebugOverlay.Box( sdfbox.Mins, sdfbox.Maxs, Color.Green );
		}

		//DebugOverlay.Box( SmokeSDFBounds.Mins, SmokeSDFBounds.Maxs, Color.Red );
	}
	List<Transform> goals = new();
	protected virtual void Think()
	{

	}

	public SmokeRenderObject so;

	public void OnRender( SceneWorld world )
	{
		//check if is in view
		//if ( Camera.Rotation.Forward.Dot( (Position - Camera.Position).Normal ) > 0.5f )
		//{
		//	return;
		//}
		//attributes.Set( "CubeTexture", _texture );
		if ( !so.IsValid() )
		{
			so = new( new(), this );
		}
		so.Batchable = false;
		so.Update();
		//so.Flags.NeedsLightProbe = true;

		//_boundsBuffer.Draw( smokematerial, attributes );
	}

	public void SetGraphicsParameters()
	{
		ShapeConstantBuffer_tss scb = new();
		scb.shapePropertiesss = new( 110 );

		/* scb.shapeInstanc = new()
		{
			nStartEllipsoid = 0,
			nEndEllipsoid = 0,
			nEndBox = 1,
			nEndCylinder = 1,
		}; */
		int nEndEllipsoid = 0;
		int nEndBox = 0;
		int nEndCylinder = 0;


		var sorted = SmokeSDFs.OrderBy( x => x.Type ).ToList();

		for ( int i = 0; i < sorted.Count; i++ )
		{
			var sdf = sorted[i];
			if ( sdf.Type == SmokeSDF.SDFType.Ellipsoid )
			{
				nEndEllipsoid++;
				nEndCylinder++;
				nEndBox++;
			}
			if ( sdf.Type == SmokeSDF.SDFType.Box )
			{
				nEndBox++;
				nEndCylinder++;
			}
			if ( sdf.Type == SmokeSDF.SDFType.Cylinder )
			{
				nEndCylinder++;
			}
			//Log.Info( sdf.ToString() );
			scb.shapePropertiesss.Add( sdf.Encode( this ) );
		}




		scb.shapeInstance = new()
		{
			nStartEllipsoid = 0,
			nEndEllipsoid = nEndEllipsoid,
			nEndBox = nEndBox,
			nEndCylinder = nEndCylinder,
		};

		so.Attributes.Set( "WorldPosition", 1 - so.Position );
		so.Attributes.SetData( "ShapeInstancesConstantbuffer", scb.shapeInstance );
		so.Attributes.SetData( "ShapeConstantBuffer_tss", scb.shapePropertiesss );
	}
}

