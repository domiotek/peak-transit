using System;
using System.Collections.Generic;
using Newtonsoft.Json;

namespace PT.Models.WorldDefinition;

public partial class WorldDefinition : SlimWorldDefinition
{
    [JsonProperty("map", Required = Required.Always)]
    public required MapDefinition MapDefinition { get; init; }

    [JsonProperty("network", Required = Required.Always)]
    public required NetworkDefinition NetworkDefinition { get; init; }

    [JsonProperty("transport", Required = Required.Always)]
    public required TransportDefinition TransportDefinition { get; init; }

    public new Godot.Collections.Dictionary Serialize()
    {
        var dict = new Godot.Collections.Dictionary
        {
            ["name"] = Name,
            ["description"] = Description,
            ["createdAt"] = CreatedAt,
            ["builtIn"] = BuiltIn,
            ["filePath"] = FilePath,
            ["map"] = MapDefinition.Serialize(),
            ["network"] = NetworkDefinition.Serialize(),
            ["transport"] = TransportDefinition.Serialize(),
        };
        return dict;
    }

    public static WorldDefinition Deserialize(Godot.Collections.Dictionary dict)
    {
        return new WorldDefinition
        {
            Name = dict.TryGetValue("name", out var name) ? (string)name : "Unnamed World",
            Description = dict.TryGetValue("description", out var description)
                ? (string)description
                : "",
            CreatedAt = dict.TryGetValue("createdAt", out var createdAt)
                ? (string)createdAt
                : DateTime.UtcNow.ToString(),
            BuiltIn = dict.TryGetValue("builtIn", out var builtIn) ? (bool)builtIn : false,
            FilePath = dict.TryGetValue("filePath", out var filePath)
                ? (string)filePath
                : string.Empty,
            MapDefinition = MapDefinition.Deserialize(
                dict.TryGetValue("map", out var map) ? (Godot.Collections.Dictionary)map : []
            ),
            NetworkDefinition = NetworkDefinition.Deserialize(
                dict.TryGetValue("network", out var network)
                    ? (Godot.Collections.Dictionary)network
                    : []
            ),
            TransportDefinition = TransportDefinition.Deserialize(
                dict.TryGetValue("transport", out var transport)
                    ? (Godot.Collections.Dictionary)transport
                    : []
            ),
        };
    }
}
