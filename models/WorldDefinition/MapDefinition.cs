using System.Numerics;
using Newtonsoft.Json;
using PT.Helpers;

namespace PT.Models.WorldDefinition;

public class MapDefinition
{
    [JsonProperty("size", Required = Required.Always), JsonConverter(typeof(Vector2JsonConverter))]
    public required Vector2 MapSize { get; set; }

    [JsonProperty("initialPosition"), JsonConverter(typeof(Vector2JsonConverter))]
    public Vector2 InitialMapPos { get; set; } = new Vector2(0, 0);

    [JsonProperty("initialZoom")]
    public float InitialZoom { get; set; } = 1.0f;

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

    public static MapDefinition Deserialize(Godot.Collections.Dictionary data)
    {
        return new MapDefinition
        {
            MapSize = data.TryGetValue("size", out var size)
                ? new Vector2(((Godot.Vector2)size).X, ((Godot.Vector2)size).Y)
                : new Vector2(5000, 5000),
            InitialMapPos = data.TryGetValue("initialPosition", out var initialPosition)
                ? new Vector2(
                    ((Godot.Vector2)initialPosition).X,
                    ((Godot.Vector2)initialPosition).Y
                )
                : new Vector2(0, 0),
            InitialZoom = data.TryGetValue("initialZoom", out var initialZoom)
                ? (float)initialZoom
                : 1.0f,
        };
    }
}
