using System.Collections.Generic;
using System.Numerics;
using Godot.Collections;
using Newtonsoft.Json;

namespace PT.Models.WorldDefinition.Network;

public enum IntersectionType
{
    Default,
    TrafficLights,
}

public class NetNodeInfo
{
    [JsonIgnore]
    public int Id { get; set; }

    [
        JsonProperty("pos", Required = Required.Always),
        JsonConverter(typeof(PT.Helpers.Vector2JsonConverter))
    ]
    public required Vector2 Position { get; set; }

    [JsonProperty("intersection")]
    public IntersectionType IntersectionType { get; set; } = IntersectionType.Default;

    [JsonProperty("priSegments")]
    public List<int> PrioritySegments { get; set; } = [];

    [JsonProperty("stpSegments")]
    public List<int> StopSegments { get; set; } = [];

    public Dictionary Serialize()
    {
        return new Dictionary
        {
            ["id"] = Id,
            ["pos"] = new Godot.Vector2(Position.X, Position.Y),
            ["intersection"] = (int)IntersectionType,
            ["priSegments"] = new Array<int>(PrioritySegments),
            ["stpSegments"] = new Array<int>(StopSegments),
        };
    }

    public static NetNodeInfo Deserialize(Dictionary data)
    {
        return new NetNodeInfo
        {
            Id = data.TryGetValue("id", out var id) ? (int)id : 0,
            Position = data.TryGetValue("pos", out var pos)
                ? new Vector2(((Godot.Vector2)pos).X, ((Godot.Vector2)pos).Y)
                : new Vector2(0, 0),
            IntersectionType = data.TryGetValue("intersection", out var intersection)
                ? (IntersectionType)(int)intersection
                : IntersectionType.Default,
            PrioritySegments = data.TryGetValue("priSegments", out var priSegments)
                ? [.. priSegments.AsGodotArray<int>()]
                : [],
            StopSegments = data.TryGetValue("stpSegments", out var stpSegments)
                ? [.. stpSegments.AsGodotArray<int>()]
                : [],
        };
    }
}
