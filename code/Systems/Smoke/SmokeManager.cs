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



	public override void Spawn()
	{
		base.Spawn();
		Transmit = TransmitType.Always;
	}


	[ConCmd.Server]
	public static void ClearSmoke()
	{
		foreach ( var ent in Entity.All.OfType<SmokeInstance>() )
		{
			ent.Delete();
		}
		ClearSmokeClient();
		SmokeInstance.SmokeSDFs.Clear();
		SmokeInstance.SubtractionSmokeSDFs.Clear();
	}
	[ClientRpc]
	public static void ClearSmokeClient()
	{
		SmokeInstance.SmokeSDFs.Clear();
		SmokeInstance.SubtractionSmokeSDFs.Clear();
	}



}
