using System.Collections.Generic;
using Godot;

namespace PTS.DependencyProvider;

public partial class DIContainer : Node
{
    private static Dictionary<string, object> _instances { get; } = [];
    private static List<Callable> _onReadyCallbacks { get; } = [];

    private static bool _isFinalized = false;

    public static void Register(string name, GodotObject instance)
    {
        if (_isFinalized)
        {
            GD.PrintErr("DIContainer: Cannot register new instances after finalization.");
            return;
        }

        if (_instances.ContainsKey(name))
        {
            GD.PrintErr($"DIContainer: Instance with name {name} already exists.");
            return;
        }

        _instances[name] = instance;
    }

    public static void Register<T>(string name, T instance)
    {
        if (_isFinalized)
        {
            GD.PrintErr("DIContainer: Cannot register new instances after finalization.");
            return;
        }

        if (_instances.ContainsKey(name))
        {
            GD.PrintErr($"DIContainer: Instance with name {name} already exists.");
            return;
        }

        _instances[name] = instance;
    }

    public static GodotObject Inject(string name)
    {
        if (_instances.TryGetValue(name, out var instance))
        {
            return instance as GodotObject;
        }

        GD.PrintErr($"DIContainer: Instance with name {name} not found.");
        return null;
    }

    public static T Inject<T>(string name)
        where T : class
    {
        if (_instances.TryGetValue(name, out var instance) && instance is T typedInstance)
        {
            return typedInstance;
        }

        GD.PrintErr(
            $"DIContainer: Instance with name {name} not found or is not of type {typeof(T).Name}."
        );
        return null;
    }

    public static void AddOnReadyCallback(Callable callback)
    {
        if (callback.Target == null || callback.Method == null)
        {
            GD.PrintErr("DIContainer: Callback cannot be null.");
            return;
        }

        _onReadyCallbacks.Add(callback);
    }

    public static void FinalizeContainer()
    {
        if (_isFinalized)
        {
            GD.PrintErr("DIContainer: Already finalized.");
            return;
        }

        foreach (var callback in _onReadyCallbacks)
        {
            callback.Call();
        }

        _isFinalized = true;
    }
}
