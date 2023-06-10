using System;

namespace Sandbox.Systems.Smoke.SDFS;

public class SphereSDF : SmokeSDF
{

	public float Radius;

	public SphereSDF( Vector3 pos, float radius, float pow = 1f )
	{
		Position = pos;
		Radius = radius;
		Pow = pow;

		Type = SDFType.Ellipsoid;
	}

	public override ShapeProperties_ts Encode( SmokeInstance smokeInstance )
	{
		return new ShapeProperties_ts
		{
			matWorldProxy = Matrix.CreateTranslation( smokeInstance.Position - Position ).Transpose(),
			vProxyScale = new Vector3( 0, Radius, Radius ),
			Pow = Pow
		};
	}

	public override BBox GetBounds( SmokeInstance instance )
	{
		return new BBox( Position - Radius, Position + Radius );
	}

}

