using Godot;

namespace PT.Services.Managers.Config;

[GlobalClass]
public partial class ConfigManager : GodotObject
{
    public int PathingWorkerCount { get; } = 2;

    public DebugToggles DebugToggles { get; } = new DebugToggles();
}
