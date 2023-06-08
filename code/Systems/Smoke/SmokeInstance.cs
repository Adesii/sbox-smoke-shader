using System;
using System.Collections.Generic;

namespace Sandbox.Systems.Smoke;

public partial class SmokeInstance : Entity
{
	[Net]
	public IList<SmokeVoxel> Voxels { get; set; } = new List<SmokeVoxel>();

	public static Material smokematerial => Material.Load( "shaders/smoke.vmat" );

	RenderAttributes attributes = new RenderAttributes();

	public Vector3 SmokePosition
	{
		get
		{
			return Position;
		}
		set
		{
			Position = (value + Vector3.Up * (MaxSize.z * SmokeManager.VOXEL_SIZE)).SnapToGrid( SmokeManager.VOXEL_SIZE );
		}
	}



	public override void Spawn()
	{
		base.Spawn();
		Transmit = TransmitType.Always;
	}

	public override void ClientSpawn()
	{
		base.ClientSpawn();

		_boundsBuffer = new();
		_boundsBuffer.Init( true );
		_boundsBuffer.AddCube( 0, MaxSize * SmokeManager.VOXEL_SIZE * 2, Rotation.Identity );
		attributes.Set( "CubeTexture", _texture );

		if ( _data == null )
		{
			_data = new byte[MaxSize.x * MaxSize.y * MaxSize.z];
		}

		Game.Random.NextBytes( _data );
		_texture = Texture.CreateVolume( MaxSize.x, MaxSize.y, MaxSize.z, ImageFormat.A8 ).WithDynamicUsage().Finish();
	}

	TimeSince LastUpdate;

	[GameEvent.Tick.Server]
	private void Tick()
	{
		Think();

		//DebugOverlay.Box( Position - (Vector3)(MaxSize * SmokeManager.VOXEL_SIZE), Position + MaxSize * SmokeManager.VOXEL_SIZE, Color.Red );

		//if ( LastUpdate > 0.1f )
		//{
		//	LastUpdate = 0;
		//Set all _data to 255
		UpdateAll();
		//}
	}
	float dists = 0;
	float Targetdists = 0;

	float CapsuleSDF( Vector3 p, Vector3 a, Vector3 b, float r )
	{
		Vector3 pa = p - a, ba = b - a;
		float h = (Vector3.Dot( pa, ba ) / Vector3.Dot( ba, ba )).Clamp( 0.0f, 1.0f );
		return Vector3.DistanceBetween( pa, ba * h ) - r;
	}

	[ClientRpc]
	private void UpdateAll()
	{
		//Game.Random.NextBytes( _data );
		//make a sphere 0f 255s
		if ( dists.AlmostEqual( Targetdists, 0.1f ) )
		{
			Targetdists = Game.Random.Float( 2, 6 );
		}
		dists = dists.LerpTo( Targetdists, Time.Delta );
		for ( int x = 0; x < MaxSize.x; x++ )
		{
			for ( int y = 0; y < MaxSize.y; y++ )
			{
				for ( int z = 0; z < MaxSize.z; z++ )
				{
					var pos = new Vector3Int( x, y, z );
					var index = x + y * MaxSize.x + z * MaxSize.x * MaxSize.y;
					//var dist = Vector3.DistanceBetween( pos, MaxSize / 2 );
					//if ( dist < dists + 2 )
					//{
					//smooth falloff from the center
					float distss = CapsuleSDF( pos, (Vector3)MaxSize / 2 + MathF.Sin( Time.Now + Position.Length ), (Vector3)MaxSize / 4 + Vector3.Up * 2, 0.1f );
					//distss += CapsuleSDF( (Vector3)pos - MathF.Sin( Time.Now + Position.Length ) * 3f, (Vector3)MaxSize / 6f + MathF.Sin( Time.Now + Position.Length ), (Vector3)MaxSize / 2f + Vector3.Up * 2f + MathF.Cos( Time.Now + Position.Length ), 1f );
					distss = Math.Clamp( 1.0f / distss, 0, 1 );
					//if ( distss < 0.1f )
					_data[index] = (byte)((MathF.Pow( distss, 5 )) * 200);
					//else
					//{
					//	_data[index] = 0;
					//}
					//}
					//else
					//{
					//	_data[index] = 0;
					//}
					//_data[index] = 200;
				}
			}
		}
		UpdateTexture();
	}

	protected virtual void Think()
	{

	}


	protected virtual void SetSmokeVoxel( Vector3 Position )
	{
		UpdateTexture();
	}


	private void UpdateTexture()
	{
		_texture.Update3D( _data, 0, 0, 0, MaxSize.x, MaxSize.y, MaxSize.z );
		if ( !so.IsValid() ) return;
		so.Attributes.Set( "CubeTexture", _texture );
		so.Attributes.Set( "WorldPosition", SmokePosition - (Vector3)(MaxSize * SmokeManager.VOXEL_SIZE) );
		so.Attributes.Set( "WorldSize", MaxSize * SmokeManager.VOXEL_SIZE );
	}

	Texture _texture;

	protected virtual Vector3Int MaxSize { get; set; } = new Vector3Int( 8, 8, 8 );

	byte[] _data;

	VertexBuffer _boundsBuffer;

	public SceneObject so;

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
			var mesh = new Mesh( smokematerial );
			mesh.CreateBuffers( _boundsBuffer );
			so = new( new(), Model.Builder.AddMesh( mesh ).Create() );
		}

		so.Position = Position;
		so.Flags.NeedsLightProbe = true;

		//_boundsBuffer.Draw( smokematerial, attributes );
	}

}

