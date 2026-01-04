using System.Collections.Generic;
using System.Linq;
using Godot.Collections;
using Newtonsoft.Json;
using PT.Models.WorldDefinition;

namespace PeakTransit.Models.WorldDefinition.Transport.DemandPreset;

public class DemandPresetDefinition : IDefinition<DemandPresetDefinition>
{
    [JsonProperty("tolerance")]
    public float BoredomToleranceMultiplier { get; set; } = 1.0f;

    [JsonProperty("chance")]
    public float PassengerSpawnChanceMultiplier { get; set; } = 1.0f;

    [JsonProperty("frames", Required = Required.Always)]
    public List<PresetFrameDefinition> Frames { get; set; }

    public Dictionary Serialize()
    {
        var dict = new Dictionary
        {
            ["tolerance"] = BoredomToleranceMultiplier,
            ["chance"] = PassengerSpawnChanceMultiplier,
            ["frames"] = new Array<Dictionary>(Frames.ConvertAll(frame => frame.Serialize())),
        };
        return dict;
    }

    public static DemandPresetDefinition Deserialize(Dictionary data)
    {
        var demandPreset = new DemandPresetDefinition
        {
            BoredomToleranceMultiplier = data["tolerance"].As<float>(),
            PassengerSpawnChanceMultiplier = data["chance"].As<float>(),
            Frames =
            [
                .. data["frames"]
                    .AsGodotArray()
                    .Select(frameData =>
                        PresetFrameDefinition.Deserialize(frameData.As<Dictionary>())
                    ),
            ],
        };
        return demandPreset;
    }
}
