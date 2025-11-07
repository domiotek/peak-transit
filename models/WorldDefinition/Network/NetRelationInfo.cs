using System.Collections.Generic;
using Newtonsoft.Json;
using PT.Models.Network.Buildings;

namespace PT.Models.WorldDefinition.Network;

public class NetRelationInfo
{
    [JsonProperty("lanes", Required = Required.Always)]
    public required List<NetLaneInfo> Lanes { get; init; }

    [JsonProperty("buildings")]
    public List<BuildingInfo> Buildings { get; init; } = [];

    public Godot.Collections.Dictionary Serialize()
    {
        var dict = new Godot.Collections.Dictionary
        {
            ["lanes"] = new Godot.Collections.Array<Godot.Collections.Dictionary>(
                Lanes.ConvertAll(lane => lane.Serialize())
            ),
            ["buildings"] = new Godot.Collections.Array<Godot.Collections.Dictionary>(
                Buildings.ConvertAll(building => building.Serialize())
            ),
        };
        return dict;
    }
}
