

namespace MyProject;

public partial class Player
{
	static string realm = Game.IsServer ? "server" : "client";
	static Logger eventLogger = new Logger( $"player/GameEvent/{realm}" );

	public void RunGameEvent( string eventName )
	{
		eventName = eventName.ToLowerInvariant();

		Controller.Mechanics.ToList()
			.ForEach( x => x.OnGameEvent( eventName ) );

		eventLogger.Trace( $"OnGameEvent ({eventName})" );
	}
}
