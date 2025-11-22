using System.Collections.Generic;
using System.Linq;
using Godot.Collections;
using Newtonsoft.Json;
using PT.Models.WorldDefinition.Transport;

namespace PT.Models.WorldDefinition;

public class TransportDefinition : IDefinition<TransportDefinition>
{
    [JsonProperty("stops")]
    public List<StopDefinition> Stops { get; set; } = [];

    [JsonProperty("terminals")]
    public List<TerminalDefinition> Terminals { get; set; } = [];

    public Dictionary Serialize()
    {
        var dict = new Dictionary
        {
            ["stops"] = new Array<Dictionary>(Stops.ConvertAll(n => n.Serialize())),
            ["terminals"] = new Array<Dictionary>(Terminals.ConvertAll(n => n.Serialize())),
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
        };
        return transportDefinition;
    }
}
