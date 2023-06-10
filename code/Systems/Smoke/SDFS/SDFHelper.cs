using System;
using System.Collections.Generic;
using System.Numerics;
using System.Runtime.InteropServices;
using Sandbox.Internal;

namespace Sandbox.Systems.Smoke;

public static class SDFHelper
{
	public static float SphereSDF( Vector3 p, float r )
	{
		return p.Length - r;
	}

	public static float BoxSDF( Vector3 p, Vector3 b )
	{
		Vector3 d = p.Abs() - b;
		return MathF.Min( MathF.Max( d.x, MathF.Max( d.y, d.z ) ), 0.0f ) + new Vector3( MathF.Max( d.x, 0 ), MathF.Max( d.y, 0 ), MathF.Max( d.z, 0 ) ).Length;
	}

	public static float TorusSDF( Vector3 p, Vector2 t )
	{
		Vector2 q = new Vector2( new Vector2( p.x, p.z ).Length - t.x, p.y );
		return q.Length - t.y;
	}

	public static float PlaneSDF( Vector3 p, Vector4 n )
	{
		return p.Dot( n ) + n.w;
	}

	public static float CapsuleSDF( Vector3 p, Vector3 a, Vector3 b, float r )
	{
		Vector3 pa = p - a, ba = b - a;
		float h = (pa.Dot( ba ) / ba.LengthSquared).Clamp( 0, 1 );
		return (pa - ba * h).Length - r;
	}

}

[StructLayout( LayoutKind.Sequential )]
public struct ShapeInstance_ts
{
	public int nStartEllipsoid;
	public int nEndEllipsoid;
	public int nEndBox;
	public int nEndCylinder;
}
[StructLayout( LayoutKind.Sequential )]
public struct ShapeProperties_ts
{
	//float4x3 matWorldProxy;
	public Matrix matWorldProxy;
	public Vector3 vProxyScale;
	public float Pow;
}
[StructLayout( LayoutKind.Sequential )]
public struct ShapeSettings_t
{
	public int nInstancesCount;
	public int nShapeCount; //Useful only on C++ side really
	public int nUnused1;
	public int nUnused2;
};
[StructLayout( LayoutKind.Sequential )]
public struct ShapeBounds_ts
{
	public Vector3 vBoundingCenter;
	public float fBoundingRadius;
};

[StructLayout( LayoutKind.Sequential )]
public struct ShapeConstantBuffer_tss
{

	//per instance
	//public ShapeSettings_t shapeSettings;

	public ShapeInstance_ts shapeInstance;

	//public List<ShapeBounds_ts> shapeBounds;
	public List<ShapeProperties_ts> shapePropertiesss;
}
