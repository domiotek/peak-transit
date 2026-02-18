using System.Reflection;
using Godot;

namespace PT.Services.Managers.Config;

[GlobalClass]
public partial class DebugToggles : RefCounted
{
    [Signal]
    public delegate void ToggleChangedEventHandler(string toggleName, bool value);

    public bool DrawNetworkConnections { get; private set; } = false;

    public bool DrawNetworkNodes { get; private set; } = false;

    public bool DrawCameraBounds { get; private set; } = false;

    public bool DrawNodeLayers { get; private set; } = false;

    public bool DrawLaneLayers { get; private set; } = false;

    public bool DrawLaneEndpoints { get; private set; } = false;

    public bool DrawLaneConnections { get; private set; } = false;

    public bool DrawIntersectionStoppers { get; private set; } = false;

    public bool DrawLaneSpeedLimits { get; private set; } = false;

    public bool DrawLaneUsage { get; private set; } = false;

    public bool DrawBuildingConnections { get; private set; } = false;

    public bool DrawTerminalPaths { get; private set; } = false;

    public bool UseDayNightCycle { get; private set; } = false;

    public bool IgnoreDepotConstraints { get; private set; } = false;

    public bool UseVehicleDebugIndicators { get; private set; } = false;

    public void SetToggle(string toggleName, bool value)
    {
        var property = GetType()
            .GetProperty(toggleName, BindingFlags.Public | BindingFlags.Instance);
        if (property != null && property.PropertyType == typeof(bool))
        {
            var oldValue = (bool)property.GetValue(this);
            if (oldValue != value)
            {
                property.SetValue(this, value);
                EmitSignal(SignalName.ToggleChanged, toggleName, value);
            }
        }
        else
        {
            GD.PrintErr($"DebugToggles: No boolean property named '{toggleName}' found.");
        }
    }

    public Godot.Collections.Dictionary<string, bool> ToDictionary()
    {
        var dictionary = new Godot.Collections.Dictionary<string, bool>();
        var properties = GetType().GetProperties(BindingFlags.Public | BindingFlags.Instance);

        foreach (var property in properties)
        {
            if (property.PropertyType == typeof(bool))
            {
                var value = (bool)property.GetValue(this);
                dictionary[property.Name] = value;
            }
        }

        return dictionary;
    }
}
