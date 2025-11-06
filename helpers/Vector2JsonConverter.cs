using System;
using System.Numerics;
using Newtonsoft.Json;
using Newtonsoft.Json.Linq;

namespace PT.Helpers;

public class Vector2JsonConverter : JsonConverter<Vector2>
{
    public override Vector2 ReadJson(
        JsonReader reader,
        Type objectType,
        Vector2 existingValue,
        bool hasExistingValue,
        JsonSerializer serializer
    )
    {
        if (reader.TokenType == JsonToken.Null)
        {
            return Vector2.Zero;
        }

        var token = JToken.Load(reader);

        if (token is JArray array && array.Count >= 2)
        {
            var x = array[0].ToObject<float>();
            var y = array[1].ToObject<float>();
            return new Vector2(x, y);
        }

        throw new JsonSerializationException(
            "Expected an array with at least two numeric elements to convert to Vector2."
        );
    }

    public override void WriteJson(JsonWriter writer, Vector2 value, JsonSerializer serializer)
    {
        writer.WriteStartArray();
        writer.WriteValue(value.X);
        writer.WriteValue(value.Y);
        writer.WriteEndArray();
    }
}
