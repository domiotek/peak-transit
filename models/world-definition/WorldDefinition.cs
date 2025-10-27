using Godot;

namespace PT.Constants;

[GlobalClass]
public partial class WorldDefinition : RefCounted
{
    public Vector2 MapSize { get; } = new Vector2(5000, 5000);

    public Vector2 InitialMapPos { get; } = new Vector2(0, 0);

    public float InitialZoom { get; } = 1.0f;

    public NetworkDefinition NetworkDefinition { get; } = new NetworkDefinition();
}
