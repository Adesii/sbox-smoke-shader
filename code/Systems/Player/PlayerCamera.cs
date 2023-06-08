
namespace MyProject;

public partial class PlayerCamera
{
	public Vector3 Position;
	public Rotation Rotation;


	float MoveSpeed = 100;
	public virtual void BuildInput( Player player )
	{
	}

	public virtual void Update( Player player )
	{

		if ( player.Tags.Has( "Devcam" ) )
		{

			Rotation = player.LookInput.ToRotation();
			if ( Input.Down( "run" ) )
			{
				MoveSpeed = 500;
			}
			else
			{
				MoveSpeed = 100;
			}
			Position += Rotation * Input.AnalogMove * MoveSpeed * Time.Delta;
			if ( Input.Down( "jump" ) )
			{
				Position += Vector3.Up * MoveSpeed * Time.Delta;
			}
			if ( Input.Down( "duck" ) )
			{
				Position += Vector3.Down * MoveSpeed * Time.Delta;
			}
			Camera.FirstPersonViewer = null;
		}
		else
		{
			Position = player.EyePosition;
			Rotation = player.EyeRotation;
			Camera.FirstPersonViewer = player;
		}
		Camera.FieldOfView = Game.Preferences.FieldOfView;
		Camera.ZNear = 0.5f;

		Camera.Position = Position;
		Camera.Rotation = Rotation;

		UpdatePostProcess();
	}

	protected void UpdatePostProcess()
	{
		/* var postProcess = Camera.Main.FindOrCreateHook<Sandbox.Effects.ScreenEffects>();
		postProcess.Sharpen = 0.05f;
		postProcess.Vignette.Intensity = 0.60f;
		postProcess.Vignette.Roundness = 1f;
		postProcess.Vignette.Smoothness = 0.3f;
		postProcess.Vignette.Color = Color.Black.WithAlpha( 1f );
		postProcess.MotionBlur.Scale = 0f;
		postProcess.Saturation = 1f;

		postProcess.FilmGrain.Response = 1f;
		postProcess.FilmGrain.Intensity = 0.01f; */
	}
}
