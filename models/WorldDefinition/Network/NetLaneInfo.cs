using Newtonsoft.Json;

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

public class NetLaneInfo
{
    [JsonProperty("maxSpeed")]
    public float MaxSpeed { get; set; } = -1f;

    [JsonProperty("direction")]
    public LaneDirection Direction { get; set; } = LaneDirection.Auto;

    public Godot.Collections.Dictionary Serialize()
    {
        return new Godot.Collections.Dictionary
        {
            ["maxSpeed"] = MaxSpeed,
            ["direction"] = (int)Direction,
        };
    }

    public static NetLaneInfo Deserialize(Godot.Collections.Dictionary data)
    {
        return new NetLaneInfo
        {
            MaxSpeed = data["maxSpeed"].As<float>(),
            Direction = (LaneDirection)data["direction"].AsInt32(),
        };
    }
}
