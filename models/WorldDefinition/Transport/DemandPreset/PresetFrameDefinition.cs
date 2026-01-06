using System.Collections.Generic;
using Godot.Collections;
using Newtonsoft.Json;
using PT.Models.WorldDefinition;

namespace PeakTransit.Models.WorldDefinition.Transport.DemandPreset;

public class PresetFrameDefinition : IDefinition<PresetFrameDefinition>
{
    [JsonProperty("hour", Required = Required.Always)]
    public string StartHour { get; set; }

    [JsonProperty("range", Required = Required.Always)]
    public List<int> PassengersRange { get; set; }

    [JsonProperty("chance")]
    public float? PassengerSpawnChanceMultiplier { get; set; }

    public Dictionary Serialize()
    {
        var dict = new Dictionary
        {
            ["hour"] = StartHour,
            ["range"] = new Array<int>(PassengersRange),
        };

        if (PassengerSpawnChanceMultiplier.HasValue)
        {
            dict["chance"] = PassengerSpawnChanceMultiplier.Value;
        }
        return dict;
    }

    public static PresetFrameDefinition Deserialize(Dictionary data)
    {
        var presetFrame = new PresetFrameDefinition
        {
            StartHour = data["hour"].As<string>(),
            PassengersRange = [.. data["range"].AsInt32Array()],
            PassengerSpawnChanceMultiplier = data["chance"].As<float>(),
        };
        return presetFrame;
    }
}
