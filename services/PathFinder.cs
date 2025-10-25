using System;
using System.Collections.Concurrent;
using System.Collections.Generic;
using System.Threading;
using Godot;
using Godot.Collections;
using PT.DependencyProvider;
using PT.Helpers;
using PT.Models.PathFinding;
using PT.Services.Managers.Config;

namespace PT.Services;

record WorkItem(PathingRequest Request, Callable OnResult, long RequestId, int CombinationId = 0);

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

    public void FindPath(
        int fromNodeId,
        int toNodeId,
        long requestId,
        Callable onResult,
        int forceFromEndpoint = -1,
        int forceToEndpoint = -1,
        int combinationId = 0
    )
    {
        var request = new PathingRequest(fromNodeId, toNodeId, forceFromEndpoint, forceToEndpoint);

        _queue.Enqueue(new WorkItem(request, onResult, requestId, combinationId));
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
                    request.OnResult.CallDeferred(
                        request.RequestId,
                        request.CombinationId,
                        response
                    );
                }
                catch (Exception ex)
                {
                    var response = PathingResponse.CompleteRequest(
                        request.Request,
                        PathingState.Failed,
                        []
                    );
                    request.OnResult.Call(request.RequestId, request.CombinationId, response);
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
            var (foundPath, totalCost) = AStarPathing.FindPathAStar(
                Graph,
                request.StartNodeId,
                request.EndNodeId,
                request.ForcedStartEndpointId != -1 ? request.ForcedStartEndpointId : null,
                request.ForcedEndEndpointId != -1 ? request.ForcedEndEndpointId : null
            );

            path.AddRange(foundPath);

            return request.CompleteRequest(PathingState.Completed, path, totalCost);
        }
        catch (Exception ex)
        {
            GD.PrintErr($"A* pathfinding failed: {ex.Message}");
            return request.CompleteRequest(PathingState.Failed, [], 0.0f);
        }
    }
}
