
using System;
using System.IO;
using Sandbox;

public struct Vector3Int : IEquatable<Vector3Int>
{

	internal readonly System.Numerics.Vector3 vec;

	//
	// Summary:
	//     Returns a Vector with every component set to 1
	public static readonly Vector3Int One = new Vector3Int( 1, 1, 1 );

	//
	// Summary:
	//     Returns a Vector with every component set to 0
	public static readonly Vector3Int Zero = new Vector3Int( 0, 0, 0 );

	public static readonly Vector3Int Up = new Vector3Int( 0, 0, 1 );

	public static readonly Vector3Int Down = new Vector3Int( 0, 0, -1 );

	public static readonly Vector3Int Left = new Vector3Int( 0, 1, 0 );

	public static readonly Vector3Int Right = new Vector3Int( 0, -1f, 0 );

	public static readonly Vector3Int Forward = new Vector3Int( 1, 0, 0 );

	public static readonly Vector3Int Backward = new Vector3Int( -1, 0, 0 );

	public Vector3Int Perpendicular => new Vector3Int( -y, x, z );

	public int x;

	public int y;

	public int z;

	//
	// Summary:
	//     Returns the magnitude of the vector
	public readonly float Length => vec.Length();

	//
	// Summary:
	//     This is faster than Length, so is better to use in certain circumstances
	public readonly float LengthSquared => vec.LengthSquared();

	//
	// Summary:
	//     returns true if the squared length is less than 1e-8 (which is really near zero)
	public readonly bool IsNearZeroLength => (double)LengthSquared <= 1E-08;

	//
	// Summary:
	//     Return the same vector but with a length of one
	public readonly Vector3Int Normal => System.Numerics.Vector3.Normalize( vec );

	public static Vector3Int Random => new Vector3Int( Game.Random.Float( -1f, 1f ), Game.Random.Float( -1f, 1f ), Game.Random.Float( -1f, 1f ) ).Normal * Game.Random.Float( 0f, 1f );

	/* public Vector2Int( int x )
		: this( x, x )
	{
	} */

	public Vector3Int( int x, int y, int z )
		: this( new System.Numerics.Vector3( x, y, z ) )
	{
	}
	public Vector3Int( float x, float y, float z )
		: this( new System.Numerics.Vector3( (int)x, (int)y, (int)z ) )
	{
	}

	public Vector3Int( Vector3 v )
		: this( new System.Numerics.Vector3( v.x, v.y, v.z ) )
	{
	}

	internal static float Distance( in Vector3Int a, in Vector3Int b )
	{
		return System.Numerics.Vector3.Distance( a.vec, b.vec );
	}

	public Vector3Int( System.Numerics.Vector3 v )
	{
		vec = v;
		x = (int)v.X;
		y = (int)v.Y;
		z = (int)v.Z;
	}

	public static implicit operator Vector3Int( System.Numerics.Vector3 value )
	{
		return new Vector3Int( value );
	}

	public static implicit operator Vector3Int( Vector3 value )
	{
		return new Vector3Int( value );
	}


	public static implicit operator Vector4( Vector3Int value )
	{
		return new Vector4( value.x, value.y, value.z, 0f );
	}

	public static implicit operator Vector3Int( double value )
	{
		return new Vector3Int( (float)value, (float)value, (float)value );
	}
	public static implicit operator Vector3( Vector3Int value )
	{
		return new Vector3( value.x, value.y, value.z );
	}

	public static Vector3Int operator +( Vector3Int c1, Vector3Int c2 )
	{
		return new( c1.x + c2.x, c1.y + c2.y, c1.z + c2.z );
	}
	public static Vector3 operator +( Vector3 c1, Vector3Int c2 )
	{
		return new Vector3( c1.x + c2.vec.X, c1.y + c2.vec.Y, c1.z + c2.vec.Z );
	}

	public static Vector3Int operator -( Vector3Int c1, Vector3Int c2 )
	{
		return new( c1.x - c2.x, c1.y - c2.y, c1.z - c2.z );
	}

	public static Vector3Int operator -( Vector3Int c1 )
	{
		return System.Numerics.Vector3.Negate( c1.vec );
	}

	public static Vector3Int operator *( Vector3Int c1, float f )
	{
		return c1.vec * f;
	}

	public static Vector3Int operator *( float f, Vector3Int c1 )
	{
		return c1.vec * f;
	}

	public static Vector3Int operator *( Vector3Int c1, Vector3Int c2 )
	{
		return c1.vec * c2.vec;
	}
	public static Vector3Int operator %( Vector3Int c1, int c2 )
	{
		return new( c1.x % c2, c1.y % c2, c1.z % c2 );
	}

	public static Vector3Int operator /( Vector3Int c1, Vector3Int c2 )
	{
		return c1.vec / c2.vec;
	}

	public static Vector3Int operator /( Vector3Int c1, float c2 )
	{
		return c1.vec / c2;
	}

	public readonly float Distance( Vector3Int target )
	{
		return DistanceBetween( this, target );
	}

	public static float GetDistance( Vector3Int a, Vector3Int b )
	{
		return (b - a).Length;
	}

	public static float DistanceBetween( Vector3Int a, Vector3Int b )
	{
		return (b - a).Length;
	}

	public static double GetDot( Vector3Int a, Vector3Int b )
	{
		return System.Numerics.Vector3.Dot( a.vec, b.vec );
	}

	public override string ToString()
	{
		return $"{x:0.###},{y:0.###}";
	}

	//
	// Summary:
	//     Given a string, try to convert this into a vector4. The format is "x,y,z,w".
	public static Vector3Int Parse( string str )
	{
		str = str.Trim( '[', ']', ' ', '\n', '\r', '\t', '"' );
		string[] array = str.Split( new char[5] { ' ', ',', ';', '\n', '\r' }, StringSplitOptions.RemoveEmptyEntries );
		if ( array.Length != 2 )
		{
			return default;
		}
		return new Vector3Int( array[0].ToInt(), array[1].ToInt(), array[2].ToInt() );
	}

	//
	// Summary:
	//     Snap To Grid along all 3 axes
	public readonly Vector3Int SnapToGrid( float gridSize, bool sx = true, bool sy = true, bool sz = true )
	{
		return new Vector3Int( sx ? ((float)x).SnapToGrid( gridSize ) : x, sy ? ((float)y).SnapToGrid( gridSize ) : y, sz ? ((float)z).SnapToGrid( gridSize ) : z );
	}

	//
	// Summary:
	//     Return this vector with x
	public readonly Vector3Int WithX( int x )
	{
		return new Vector3Int( x, y, z );
	}

	//
	// Summary:
	//     Return this vector with y
	public readonly Vector3Int WithY( int y )
	{
		return new Vector3Int( x, y, z );
	}

	public readonly Vector3Int WithZ( int z )
	{
		return new Vector3Int( x, y, z );
	}



	//
	// Summary:
	//     Linearly interpolate from point a to point b
	public static Vector3Int Lerp( Vector3Int a, Vector3Int b, float t, bool clamp = true )
	{
		if ( clamp )
		{
			t = t.Clamp( 0f, 1f );
		}
		return System.Numerics.Vector3.Lerp( a.vec, b.vec, t );
	}

	public void Write( BinaryWriter writer )
	{
		writer.Write( x );
		writer.Write( y );
		writer.Write( z );
	}

	public static Vector3Int Read( BinaryReader reader )
	{
		return new Vector3Int( reader.ReadInt32(), reader.ReadInt32(), reader.ReadInt32() );
	}

	public static bool operator ==( Vector3Int left, Vector3Int right )
	{
		return (left.x == right.x && left.y == right.y);
	}

	public static bool operator !=( Vector3Int left, Vector3Int right )
	{
		return !(left.x == right.x && left.y == right.y);
	}

	public static explicit operator Vector2( Vector3Int v )
	{
		return new Vector2( v.x, v.y );
	}

	public override bool Equals( object obj )
	{
		if ( obj is Vector3Int o )
		{
			return Equals( o );
		}
		return false;
	}

	public bool Equals( Vector3Int o )
	{
		return x == o.x && y == o.y;
	}

	public override int GetHashCode()
	{
		return HashCode.Combine( vec );
	}
}



