using System;
using System.Collections.Concurrent;
using System.Collections.Generic;
using System.Threading;
using Godot;
using Godot.Collections;
using PTS.DependencyProvider;
using PTS.Helpers;
using PTS.Models;
using PTS.Models.PathFinding;
using PTS.Services.Managers.Config;

namespace PTS.Services;

record WorkItem(PathingRequest Request, Callable OnResult);

[GlobalClass]
public partial class PathFinder : GodotObject
{
    private NetGraph Graph { get; set; } = new NetGraph();

    private List<Thread> FinderThreads { get; set; } = [];
    private readonly ConcurrentQueue<WorkItem> _queue = new();
    private readonly AutoResetEvent _signal = new(false);

    public PathFinder()
    {
        var configManager = CSInjector.Inject<ConfigManager>();

        for (int i = 0; i < configManager.PathingWorkerCount; i++)
        {
            var thread = new Thread(FindPathWorkerLoop)
            {
                IsBackground = true,
                Name = $"PathFinderWorker-{i}",
            };
            FinderThreads.Add(thread);
            thread.Start();
        }
    }

    public void BuildGraph(Array<GodotObject> nodes)
    {
        foreach (var nodeObject in nodes)
        {
            var netNode = Models.Mappings.NetworkNode.Map(nodeObject);

            Graph.AddNode(netNode);
        }
    }

    public void FindPath(int fromNodeId, int toNodeId, Callable onResult)
    {
        var request = new PathingRequest(fromNodeId, toNodeId);

        _queue.Enqueue(new WorkItem(request, onResult));
        _signal.Set();
    }

    private void FindPathWorkerLoop()
    {
        while (true)
        {
            _signal.WaitOne();

            while (_queue.TryDequeue(out var request))
            {
                try
                {
                    var response = ProcessPathingRequest(request.Request);
                    request.OnResult.Call(response);
                }
                catch (Exception ex)
                {
                    var response = PathingResponse.CompleteRequest(
                        request.Request,
                        PathingState.Failed,
                        []
                    );
                    request.OnResult.Call(response);
                    GD.PrintErr($"Error processing pathing request: {ex.Message}");
                }
            }
        }
    }

    private PathingResponse ProcessPathingRequest(PathingRequest request)
    {
        try
        {
            var path = new Array<PathStep>();
            path.AddRange(
                AStarPathing.FindPathAStar(Graph, request.StartNodeId, request.EndNodeId)
            );

            return request.CompleteRequest(PathingState.Completed, path);
        }
        catch (Exception ex)
        {
            GD.PrintErr($"A* pathfinding failed: {ex.Message}");
            return request.CompleteRequest(PathingState.Failed, []);
        }
    }
}
