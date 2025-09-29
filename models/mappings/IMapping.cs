using Godot;

namespace PT.Models.Mappings;

public interface IMapping<T>
{
    static abstract T Map(GodotObject obj);
}
