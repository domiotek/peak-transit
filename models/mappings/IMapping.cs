using Godot;

namespace PTS.Models.Mappings;

public interface IMapping<T>
{
    static abstract T Map(GodotObject obj);
}
