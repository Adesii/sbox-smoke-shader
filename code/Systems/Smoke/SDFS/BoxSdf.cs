using System;
using System.Numerics;

namespace Sandbox.Systems.Smoke.SDFS;

public class BoxSDF : SmokeSDF
{
	public Vector3 Size;

	public BoxSDF( Vector3 pos, Vector3 size, float pow = 1f )
	{
		Position = pos;
		Size = size;
		Pow = pow;

		Type = SDFType.Box;
	}


	public override float GetDistance( Vector3 pos )
	{
		return SDFHelper.BoxSDF( pos - Position, Size );
	}

	public override ShapeProperties_ts Encode( SmokeRenderObject instance )
	{
		ShapeProperties_ts props = new();
		props.matWorldProxy = GetMatrix( instance );
		props.vProxyScale = Size;
		props.Pow = Pow;
		return props;
	}

	public Matrix GetMatrix( SmokeRenderObject instance )
	{
		return Matrix.CreateRotation( Rotation ) * Matrix.CreateTranslation( instance.Position - Position ).Transpose();
	}

	public override string ToString()
	{
		return $"BoxSDF: {Position}, {Size}";
	}

	public override BBox GetBounds( SmokeRenderObject instance )
	{
		Matrix mat = GetMatrix( instance );
		BBox box = new();
		//add all 8 points of the box
		box = box.AddPoint( new Vector3( -Size.x, -Size.y, -Size.z ) * 1.5f );
		box = box.AddPoint( new Vector3( -Size.x, -Size.y, Size.z ) * 1.5f );
		box = box.AddPoint( new Vector3( -Size.x, Size.y, -Size.z ) * 1.5f );
		box = box.AddPoint( new Vector3( -Size.x, Size.y, Size.z ) * 1.5f );

		box = box.AddPoint( new Vector3( Size.x, -Size.y, -Size.z ) * 1.5f );
		box = box.AddPoint( new Vector3( Size.x, -Size.y, Size.z ) * 1.5f );
		box = box.AddPoint( new Vector3( Size.x, Size.y, -Size.z ) * 1.5f );
		box = box.AddPoint( new Vector3( Size.x, Size.y, Size.z ) * 1.5f );

		//box = box.Rotate( Rotation.Inverse );
		box = box.Translate( (Position) );


		return box;
	}
}

