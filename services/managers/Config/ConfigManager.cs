using Godot;

namespace PT.Services.Managers.Config;

[GlobalClass]
public partial class ConfigManager : RefCounted
{
    public int PathingWorkerCount { get; } = 2;

    public bool AutoQuickLoad { get; } = false;

    public string BuiltInWorldDirectory { get; } = "res://assets/worlds/";

    public string DefaultWorldFileName { get; } = "default_world.json";

    public string WorldDirectory { get; } = "user://worlds/";

    public bool AutoFillDepotStopsOnLoad { get; } = true;

    public DebugToggles DebugToggles { get; } = new DebugToggles();
}
