using System.Collections.Generic;
using System.Linq;
using Godot.Collections;
using Newtonsoft.Json;
using PT.Models.WorldDefinition.Transport;

namespace PT.Models.WorldDefinition;

public class TransportDefinition : IDefinition<TransportDefinition>
{
    [JsonProperty("stops")]
    public required List<StopDefinition> Stops { get; set; } = [];

    [JsonProperty("terminals")]
    public required List<TerminalDefinition> Terminals { get; set; } = [];

    [JsonProperty("depots")]
    public required List<DepotDefinition> Depots { get; set; } = [];

    [JsonProperty("lines")]
    public required List<LineDefinition> Lines { get; set; } = [];

    public Dictionary Serialize()
    {
        var dict = new Dictionary
        {
            ["stops"] = new Array<Dictionary>(Stops.ConvertAll(n => n.Serialize())),
            ["terminals"] = new Array<Dictionary>(Terminals.ConvertAll(n => n.Serialize())),
            ["depots"] = new Array<Dictionary>(Depots.ConvertAll(n => n.Serialize())),
            ["lines"] = new Array<Dictionary>(Lines.ConvertAll(n => n.Serialize())),
        };
        return dict;
    }

    public static TransportDefinition Deserialize(Dictionary data)
    {
        var transportDefinition = new TransportDefinition
        {
            Stops =
            [
                .. data["stops"]
                    .AsGodotArray()
                    .Select(stopData =>
                        StopDefinition.Deserialize(stopData.AsGodotDictionary() ?? [])
                    ),
            ],
            Terminals =
            [
                .. data["terminals"]
                    .AsGodotArray()
                    .Select(terminalData =>
                        TerminalDefinition.Deserialize(terminalData.AsGodotDictionary() ?? [])
                    ),
            ],
            Depots =
            [
                .. data["depots"]
                    .AsGodotArray()
                    .Select(depotData =>
                        DepotDefinition.Deserialize(depotData.AsGodotDictionary() ?? [])
                    ),
            ],
            Lines =
            [
                .. data["lines"]
                    .AsGodotArray()
                    .Select(lineData =>
                        LineDefinition.Deserialize(lineData.AsGodotDictionary() ?? [])
                    ),
            ],
        };
        return transportDefinition;
    }
}
