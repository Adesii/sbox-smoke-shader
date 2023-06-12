using System;
using Sandbox.Systems.Smoke.SDFS;

namespace Sandbox.Systems.Smoke;

public class CSSmoke : SmokeInstance
{

	float ExpansionRate = 0.5f;
	float MaxSize = 110f;


	private CapsuleSDF smokesdf;

	private int index;

	private float LifeTime = 10f;

	public List<CapsuleSDF> BulletHoles = new();
	public List<TimeSince> BulletHolesTime = new();

	public override void ClientSpawn()
	{
		base.ClientSpawn();
		smokesdf = new CapsuleSDF( Position, 5, 5f, 1f );
		SmokeSDFs.Add( smokesdf );
		index = SmokeSDFs.Count - 1;
		InstanceSmokeSDFs.Add( smokesdf );
		StartExpansion = 0;
	}
	public override void Spawn()
	{
		base.Spawn();
		StartExpansion = 0;
	}

	protected override void OnDestroy()
	{
		base.OnDestroy();
		if ( Game.IsServer ) return;
		SmokeSDFs.Remove( smokesdf );
		foreach ( var sdf in BulletHoles )
		{
			SubtractionSmokeSDFs.Remove( sdf );
		}
	}

	protected override void Think()
	{
		base.Think();
		if ( StartExpansion > LifeTime + 2.5f )
		{
			//Remove the smoke after 4 seconds
			Delete();
		}
	}

	private TimeSince StartExpansion;

	protected override void ThinkClient()
	{

		smokesdf.Length = 1;
		smokesdf.Rotation = Rotation.FromPitch( 90 );

		for ( int i = 0; i < BulletHoles.Count; i++ )
		{
			CapsuleSDF bulletHole = BulletHoles[i];
			bulletHole.Length = bulletHole.Length.LerpTo( 1000f, Time.Delta * 5f );
			if ( BulletHolesTime[i] > 2f )
			{
				bulletHole.Radius = bulletHole.Radius.LerpTo( 0f, Time.Delta * 2f );
				if ( bulletHole.Radius < 1f )
				{
					BulletHoles.RemoveAt( i );
					BulletHolesTime.RemoveAt( i );
					SubtractionSmokeSDFs.Remove( bulletHole );
				}
			}
			else
			{
				bulletHole.Radius = bulletHole.Radius.LerpTo( 10f, Time.Delta * 5f );

			}
		}

		if ( StartExpansion > LifeTime )
		{
			smokesdf.Pow = smokesdf.Pow.LerpTo( 0, Time.Delta / 4 );
			//DebugOverlay.ScreenText( $"Pow: {smokesdf.Pow}", index );
			//smokesdf.Radius = smokesdf.Radius.LerpTo( 1000, Time.Delta );
		}

		smokesdf.Radius = SmokeEasing( StartExpansion ) * MaxSize;
	}
	//Replicate the smoke expansion as seen in the cs2 smoke
	//2x²{0<=x<=0.5}
	//1-(1/(5*(2x-0.8)+1)){0.5<=x}
	public float SmokeEasing( float x )
	{
		if ( x <= 0.5f )
		{
			return 2 * x * x;
		}
		else
		{
			return 1 - (1 / (5 * (2 * x - 0.8f) + 1));
		}
	}

	public void AddBulletHole( TraceResult traceResult, Vector3 Direction )
	{
		//Create a Subtraction capsule from start ray to end ray with some padding on both sides
		//This is to prevent the smoke from being cut off by the bullet hole
		var start = traceResult.StartPosition;
		var end = traceResult.EndPosition;
		var dir = Direction.Normal;
		var length = (end - start).Length;
		var capsule = new CapsuleSDF( start, start + (Direction * 1000), 0f, 0f );
		BulletHoles.Add( capsule );
		SubtractionSmokeSDFs.Add( capsule );

		BulletHolesTime.Add( 0 );
	}



}

