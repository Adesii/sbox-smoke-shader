using System;

namespace Sandbox.Systems.Smoke;

public partial class SmokeManager : Entity
{
	public const int VOXEL_SIZE = 8;

	private static SmokeManager _instance;

	public static SmokeManager Instance
	{
		get
		{
			if ( _instance == null && Game.IsServer )
			{
				_instance = new();
			}
			if ( _instance == null && Game.IsClient )
			{
				_instance = Entity.All.OfType<SmokeManager>().FirstOrDefault();
			}
			return _instance;
		}
	}

	public int count => Voxels.Count;

	[Net]
	public IDictionary<Vector3Int, SmokeVoxel> Voxels { get; set; } = new Dictionary<Vector3Int, SmokeVoxel>();




	public override void Spawn()
	{
		base.Spawn();
		Transmit = TransmitType.Always;
	}

	[GameEvent.Tick.Server]
	public void Tick()
	{
		foreach ( var voxel in Voxels )
		{
			DebugOverlay.Box( voxel.Key * VOXEL_SIZE, (voxel.Key * VOXEL_SIZE + (Vector3Int.One * VOXEL_SIZE)), Color.Red );


		}
	}

	[ConCmd.Server]
	public static void ClearSmoke()
	{
		foreach ( var ent in Entity.All.OfType<SmokeInstance>() )
		{
			ent.Delete();
		}
		Instance.Voxels.Clear();
	}




	public static SmokeVoxel AddSmokeVoxel( Vector3 Position, float Density = 1 )
	{
		Vector3Int pos = Position.SnapToGrid( VOXEL_SIZE ) / VOXEL_SIZE;
		if ( Instance == null ) return default;
		if ( Instance.Voxels == null )
		{
			Instance.Voxels = new Dictionary<Vector3Int, SmokeVoxel>();
		}
		if ( Instance.Voxels.ContainsKey( pos ) )
		{
			/* var voxel = Instance.Voxels[pos];
			voxel.Type = SmokeVoxelType.Smoked;
			Instance.Voxels[pos] = voxel; */
		}
		else
		{
			var smoke = new SmokeVoxel()
			{
				Type = SmokeVoxelType.Smoked
			};
			Instance.Voxels.Add( pos, smoke );
			return smoke;
		}
		return Instance.Voxels[pos];
	}

	public static void AddSmokeCube( Vector3 Position, Vector3 Extends, float Density = 1 )
	{
		var min = Position - Extends;
		var max = Position + Extends;
		for ( var x = min.x; x < max.x; x += VOXEL_SIZE )
		{
			for ( var y = min.y; y < max.y; y += VOXEL_SIZE )
			{
				for ( var z = min.z; z < max.z; z += VOXEL_SIZE )
				{
					AddSmokeVoxel( new Vector3( x, y, z ), Density );
				}
			}
		}

	}



}
