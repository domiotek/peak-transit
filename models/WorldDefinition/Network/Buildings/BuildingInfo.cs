using Newtonsoft.Json;

namespace PT.Models.Network.Buildings;

public class BuildingInfo
{
    [JsonProperty("type")]
    public required BuildingType Type { get; set; }

    [JsonProperty("offset")]
    public required float OffsetPosition { get; set; }

    public Godot.Collections.Dictionary Serialize()
    {
        return new Godot.Collections.Dictionary
        {
            ["type"] = (int)Type,
            ["offset"] = OffsetPosition,
        };
    }

    public static BuildingInfo Deserialize(Godot.Collections.Dictionary data)
    {
        return new BuildingInfo
        {
            Type = data.TryGetValue("type", out var type)
                ? (BuildingType)(int)type
                : BuildingType.Residential,
            OffsetPosition = data.TryGetValue("offset", out var offset) ? (float)offset : 0f,
        };
    }
}
