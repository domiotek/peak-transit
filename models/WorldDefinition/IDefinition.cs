using Godot.Collections;

namespace PT.Models.WorldDefinition;

public interface IDefinition<T>
{
    public Dictionary Serialize();

    public static abstract T Deserialize(Dictionary data);
}
