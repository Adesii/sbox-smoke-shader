using System;

namespace Sandbox.Systems.Smoke;

public class SmokeSDF
{
	public enum SDFType
	{
		Ellipsoid,
		Box,
		Cylinder,
	}
	public Vector3 Position;
	public Rotation Rotation;

	public SDFType Type = SDFType.Ellipsoid;

	public float Pow = 1f;

	public virtual float GetDistance( Vector3 pos )
	{
		return 0;
	}

	public virtual ShapeProperties_ts Encode( SmokeRenderObject smokeInstance )
	{
		return default;
	}

	public virtual BBox GetBounds( SmokeRenderObject instance )
	{
		return new BBox( Position - 1, Position + 1 );
	}
}

