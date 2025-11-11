using System;
using System.Collections.Generic;
using Godot;

public class GodotObjectCollection<T> : List<T>, IDisposable
{
    public GodotObjectCollection()
        : base() { }

    public GodotObjectCollection(IEnumerable<T> collection)
        : base(collection) { }

    public void Dispose()
    {
        foreach (var item in this)
        {
            if (item is GodotObject obj)
            {
                obj.Free();
            }
        }
        Clear();
        GC.SuppressFinalize(this);
    }
}
