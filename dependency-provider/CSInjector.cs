using System;
using System.Collections.Generic;
using Godot;
using PTS.Constants;
using PTS.Managers;
using PTS.Services;
using PTS.Services.Adapters;
using PTS.Services.Managers;

namespace PTS.DependencyProvider;

public partial class CSInjector : Node
{
    private static readonly Dictionary<string, object> _adapters = [];

    public override void _Ready()
    {
        DIContainer.Register("ConfigManager", new ConfigManager());
        DIContainer.Register("LaneCalculator", new LaneCalculator());
        DIContainer.Register("PathFinder", new PathFinder());

        DIContainer.Register("NetworkDefinition", new NetworkDefinition());

        RegisterAdapter("NetworkManager", typeof(NetworkManagerAdapter));

        DIContainer.FinalizeContainer();
    }

    public static T Inject<T>()
        where T : class
    {
        return _adapters.TryGetValue(typeof(T).Name, out var adapter)
            ? adapter as T
            : DIContainer.Inject(typeof(T).Name) as T;
    }

    public static T Inject<T>(string key)
        where T : class
    {
        return _adapters.TryGetValue(key, out var adapter)
            ? adapter as T
            : DIContainer.Inject<T>(key);
    }

    public static void RegisterAdapter(string baseName, Type adapter)
    {
        if (adapter == null)
        {
            throw new ArgumentNullException(nameof(adapter), "Adapter cannot be null");
        }

        if (_adapters.ContainsKey(baseName))
        {
            throw new InvalidOperationException(
                $"Adapter for dependency '{baseName}' is already registered."
            );
        }

        var baseInstance =
            DIContainer.Inject(baseName)
            ?? throw new InvalidOperationException(
                $"Base instance for '{baseName}' is not registered."
            );

        var adapterInstance =
            Activator.CreateInstance(adapter, baseInstance)
            ?? throw new InvalidOperationException(
                $"Failed to create adapter instance for '{baseName}'."
            );
        _adapters[baseName] = adapterInstance;
    }
}
