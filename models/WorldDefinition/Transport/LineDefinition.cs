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

    public required List<List<RouteStepDefinition>> Routes { get; set; } = [];

    public Godot.Collections.Dictionary Serialize()
    {
        var dict = new Godot.Collections.Dictionary
        {
            ["displayNumber"] = DisplayNumber,
            ["color"] = ColorHex,
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
