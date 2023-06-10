using System;

namespace Sandbox.Systems.Smoke.SDFS;

public class CylinderSDF : SmokeSDF
{

	public float Radius;
	public float Length;

	public CylinderSDF( Vector3 pos, float radius, float length, float pow = 1f )
	{
		Position = pos;
		Radius = radius;
		Length = length;
		Pow = pow;

		Type = SDFType.Cylinder;
	}

	public override ShapeProperties_ts Encode( SmokeInstance smokeInstance )
	{
		return new ShapeProperties_ts
		{
			matWorldProxy = Matrix.CreateRotation( Rotation ) * Matrix.CreateTranslation( smokeInstance.Position - Position ).Transpose(),
			vProxyScale = new Vector3( Length, Radius, Radius ),
			Pow = Pow
		};
	}

	public override BBox GetBounds( SmokeInstance instance )
	{
		return new BBox( Position - (Radius + Length), Position + (Radius + Length) );
	}

}

