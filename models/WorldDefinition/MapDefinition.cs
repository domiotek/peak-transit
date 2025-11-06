using System.Numerics;
using Newtonsoft.Json;
using PT.Helpers;

namespace PT.Models.WorldDefinition;

public class MapDefinition
{
    [JsonProperty("size"), JsonConverter(typeof(Vector2JsonConverter))]
    public required Vector2 MapSize { get; init; }

    [JsonProperty("initialPosition"), JsonConverter(typeof(Vector2JsonConverter))]
    public Vector2 InitialMapPos { get; } = new Vector2(0, 0);

    [JsonProperty("initialZoom")]
    public float InitialZoom { get; } = 1.0f;

    public Godot.Collections.Dictionary Serialize()
    {
        var dict = new Godot.Collections.Dictionary
        {
            ["size"] = new Godot.Vector2(MapSize.X, MapSize.Y),
            ["initialPosition"] = new Godot.Vector2(InitialMapPos.X, InitialMapPos.Y),
            ["initialZoom"] = InitialZoom,
        };
        return dict;
    }
}
