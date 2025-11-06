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
}
