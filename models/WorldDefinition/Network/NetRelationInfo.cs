using System.Collections.Generic;
using System.Linq;
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

    public static NetRelationInfo Deserialize(Godot.Collections.Dictionary data)
    {
        return new NetRelationInfo
        {
            Lanes = data.TryGetValue("lanes", out var lanes)
                ?
                [
                    .. lanes
                        .AsGodotArray<Godot.Collections.Dictionary>()
                        .ToArray()
                        .Select(laneData => NetLaneInfo.Deserialize(laneData ?? [])),
                ]
                : [],
            Buildings = data.TryGetValue("buildings", out var buildings)
                ?
                [
                    .. buildings
                        .AsGodotArray<Godot.Collections.Dictionary>()
                        .ToArray()
                        .Select(buildingData => BuildingInfo.Deserialize(buildingData ?? [])),
                ]
                : [],
        };
    }
}
