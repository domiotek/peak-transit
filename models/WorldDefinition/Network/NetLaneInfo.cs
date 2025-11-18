using System.Collections.Generic;
using System.Linq;
using Godot.Collections;
using Newtonsoft.Json;
using PT.Models.PathFinding;

namespace PT.Models.WorldDefinition.Network;

public enum LaneDirection
{
    Auto,
    Forward,
    All,
    ForwardRight,
    Right,
    Backward,
    Left,
    ForwardLeft,
}

public enum BaseLaneDirection
{
    Forward,
    Backward,
    Left,
    Right,
}

public class NetLaneInfo
{
    [JsonProperty("maxSpeed")]
    public float MaxSpeed { get; set; } = -1f;

    [JsonProperty("direction")]
    public LaneDirection Direction { get; set; } = LaneDirection.Auto;

    [JsonProperty("allowedVehicles")]
    public System.Collections.Generic.Dictionary<
        BaseLaneDirection,
        List<VehicleCategory>
    > AllowedVehiclesPerDirection { get; set; } =
        new System.Collections.Generic.Dictionary<BaseLaneDirection, List<VehicleCategory>>();

    public Dictionary Serialize()
    {
        var allowedVehiclesDict = new Dictionary();

        foreach (var kvp in AllowedVehiclesPerDirection)
        {
            allowedVehiclesDict[(int)kvp.Key] = kvp.Value.Select(vc => (int)vc).ToArray();
        }

        return new Dictionary
        {
            ["maxSpeed"] = MaxSpeed,
            ["direction"] = (int)Direction,
            ["allowedVehicles"] = allowedVehiclesDict,
        };
    }

    public static NetLaneInfo Deserialize(Dictionary data)
    {
        return new NetLaneInfo
        {
            MaxSpeed = data["maxSpeed"].As<float>(),
            Direction = (LaneDirection)data["direction"].AsInt32(),
            AllowedVehiclesPerDirection = data["allowedVehicles"]
                .As<Dictionary>()
                .ToDictionary(
                    kv => (BaseLaneDirection)kv.Key.AsInt32(),
                    kv => kv.Value.AsInt32Array().Select(i => (VehicleCategory)i).ToList()
                ),
        };
    }
}
