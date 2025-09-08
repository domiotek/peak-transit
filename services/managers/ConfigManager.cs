using Godot;

namespace PTS.Services.Managers;

[GlobalClass]
public partial class ConfigManager : GodotObject
{
    public int PathingWorkerCount { get; } = 2;

    // Debug toggles

    public bool DrawNetworkConnections { get; } = false;

    public bool DrawNetworkNodes { get; } = false;

    public bool DrawCameraBounds { get; } = false;

    public bool DrawNodeLayers { get; } = false;

    public bool DrawLaneLayers { get; } = false;

    public bool DrawLaneEndpoints { get; } = false;

    public bool DrawLaneEndpointIds { get; } = false;

    public bool PrintIntersectionSegmentsOrientations { get; } = false;

    public bool DrawLaneConnections { get; } = false;
}
