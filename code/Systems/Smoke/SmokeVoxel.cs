namespace Sandbox.Systems.Smoke;

[Flags]
public enum SmokeVoxelType
{
	Empty = 0,
	Occupied = 1,
	Smoked = 2,
}
public struct SmokeVoxel
{
	public SmokeVoxelType Type;
}

