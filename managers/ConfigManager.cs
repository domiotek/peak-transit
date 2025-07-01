using Godot;

namespace PTS.Managers;

[GlobalClass]
public partial class ConfigManager : Node
{
    public bool DrawNetworkConnections { get; set; } = false;

    public bool DrawNetworkNodes { get; set; } = false;

    public bool DrawCameraBounds { get; set; } = false;

    public bool DrawNodeLayers { get; set; } = false;

    public bool DrawLaneLayers { get; set; } = false;
}
