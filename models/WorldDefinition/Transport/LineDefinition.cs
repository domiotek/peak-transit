using System.Collections.Generic;
using System.Linq;
using Newtonsoft.Json;

namespace PT.Models.WorldDefinition.Transport;

public class LineDefinition : IDefinition<LineDefinition>
{
    [JsonProperty("displayNumber")]
    public required int DisplayNumber { get; set; } = -1;

    [JsonProperty("color")]
    public required string ColorHex { get; set; } = "#FFFFFF";

    [JsonProperty("frequency", Required = Required.Always)]
    public required int FrequencyMinutes { get; set; }

    [JsonProperty("minLayover", Required = Required.Always)]
    public required int MinLayoverMinutes { get; set; }

    [JsonProperty("startTime")]
    public required string StartTime { get; set; }

    [JsonProperty("endTime")]
    public required string EndTime { get; set; }

    [JsonProperty("routes")]
    public required List<List<RouteStepDefinition>> Routes { get; set; } = [];

    public Godot.Collections.Dictionary Serialize()
    {
        var dict = new Godot.Collections.Dictionary
        {
            ["displayNumber"] = DisplayNumber,
            ["color"] = ColorHex,
            ["frequency"] = FrequencyMinutes,
            ["minLayover"] = MinLayoverMinutes,
            ["startTime"] = StartTime,
            ["endTime"] = EndTime,
            ["routes"] =
                new Godot.Collections.Array<Godot.Collections.Array<Godot.Collections.Dictionary>>(
                    Routes.ConvertAll(
                        route => new Godot.Collections.Array<Godot.Collections.Dictionary>(
                            route.ConvertAll(step => step.Serialize())
                        )
                    )
                ),
        };
        return dict;
    }

    public static LineDefinition Deserialize(Godot.Collections.Dictionary data)
    {
        var lineDefinition = new LineDefinition
        {
            DisplayNumber = data["displayNumber"].AsInt32(),
            ColorHex = data["color"].AsString() ?? "#FFFFFF",
            FrequencyMinutes = data["frequency"].AsInt32(),
            MinLayoverMinutes = data["minLayover"].AsInt32(),
            StartTime = data["startTime"].AsString(),
            EndTime = data["endTime"].AsString(),
            Routes =
            [
                .. data["routes"]
                    .AsGodotArray()
                    .Select<Godot.Variant, List<RouteStepDefinition>>(routeData =>
                        [
                            .. routeData
                                .AsGodotArray()
                                .Select(stepData =>
                                    RouteStepDefinition.Deserialize(
                                        stepData.AsGodotDictionary() ?? []
                                    )
                                ),
                        ]
                    ),
            ],
        };
        return lineDefinition;
    }
}
