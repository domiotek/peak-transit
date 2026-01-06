#nullable enable
using System;
using System.Collections.Generic;
using System.Linq;
using Godot;
using Godot.Collections;
using PT.Models.TimeTable;

namespace PT.Helpers;

[GlobalClass]
public partial class ScheduleGenerator : RefCounted
{
    private readonly struct DepartureEvent
    {
        public DepartureEvent(double time, int terminalId, int routeId)
        {
            Time = time;
            TerminalId = terminalId;
            RouteId = routeId;
        }

        public double Time { get; }
        public int TerminalId { get; }
        public int RouteId { get; }
    }

    private sealed class BrigadeState
    {
        public int BrigadeId { get; init; }
        public int TerminalId { get; set; }
        public double AvailableAt { get; set; }
        public List<Trip> Trips { get; } = new();
    }

    public Array<Dictionary> GenerateSchedule(
        Dictionary routeData,
        double headwayMinutes,
        double minLayoverMinutes = 2.0,
        Dictionary? rawStartTime = null,
        Dictionary? rawEndTime = null
    )
    {
        if (headwayMinutes <= 0)
            throw new ArgumentException("Headway must be positive", nameof(headwayMinutes));
        if (minLayoverMinutes < 0)
            throw new ArgumentException(
                "Layover time cannot be negative",
                nameof(minLayoverMinutes)
            );

        var routes = routeData.ToDictionary(
            kvp => (int)kvp.Key,
            kvp =>
                kvp.Value.AsGodotArray()
                    .Select(step => TripStep.Deserialize((Dictionary)step))
                    .ToList()
        );

        if (
            !routes.TryGetValue(0, out var forwardRoute)
            || !routes.TryGetValue(1, out var returnRoute)
        )
            throw new ArgumentException(
                "Route data must contain both forward (0) and return (1) routes."
            );
        if (forwardRoute.Count == 0 || returnRoute.Count == 0)
            throw new ArgumentException("Routes cannot be empty.");

        TimeOfDay? startTime =
            rawStartTime != null && rawStartTime.Count > 0
                ? TimeOfDay.Deserialize(rawStartTime)
                : null;
        TimeOfDay? endTime =
            rawEndTime != null && rawEndTime.Count > 0 ? TimeOfDay.Deserialize(rawEndTime) : null;
        double startMinutes = startTime != null ? startTime.Hour * 60 + startTime.Minute : 0;
        double endMinutes = endTime != null ? endTime.Hour * 60 + endTime.Minute : 0;

        if (endMinutes <= startMinutes)
            endMinutes += 24 * 60;

        double forwardDuration = forwardRoute.Sum(s => s.TravelTime);
        double returnDuration = returnRoute.Sum(s => s.TravelTime);

        double naturalCycleMin = forwardDuration + returnDuration + 2 * minLayoverMinutes;
        int numBrigades = (int)Math.Ceiling(naturalCycleMin / headwayMinutes);

        int minInitialAtA = (int)
            Math.Ceiling((returnDuration + minLayoverMinutes) / headwayMinutes);
        int minInitialAtB = (int)
            Math.Ceiling((forwardDuration + minLayoverMinutes) / headwayMinutes);
        int minInitialTotal = minInitialAtA + minInitialAtB;
        if (numBrigades < minInitialTotal)
            numBrigades = minInitialTotal;

        double effectiveCycle = numBrigades * headwayMinutes;
        double requiredLayoverTotal = effectiveCycle - (forwardDuration + returnDuration);

        if (requiredLayoverTotal < 2 * minLayoverMinutes)
        {
            throw new ArgumentException(
                $"Strict headway infeasible with current parameters:\n"
                    + $"- Required total layover: {requiredLayoverTotal:F1} min\n"
                    + $"- Your minimum layover:  {2 * minLayoverMinutes:F1} min (2 turn-arounds)\n\n"
                    + $"Fix by:\n"
                    + $"- Increasing frequency\n"
                    + $"- Reducing minimum layover"
            );
        }

        var gridA = BuildDepartureGrid(startMinutes, endMinutes, headwayMinutes);

        var gridB = BuildDepartureGrid(startMinutes, endMinutes, headwayMinutes);

        var events = BuildDepartureEvents(gridA, gridB, endMinutes);

        var forwardStopTimes = GenerateStopTimes(forwardRoute);
        var returnStopTimes = GenerateStopTimes(returnRoute);

        var brigadeStates = InitializeBrigades(
            numBrigades,
            startMinutes,
            minInitialAtA,
            minInitialAtB
        );
        AssignDeparturesToBrigades(
            events,
            brigadeStates,
            forwardStopTimes,
            returnStopTimes,
            forwardDuration,
            returnDuration,
            minLayoverMinutes
        );

        var result = brigadeStates
            .OrderBy(b => b.BrigadeId)
            .Select(b => new BrigadeSchedule
            {
                BrigadeId = b.BrigadeId,
                Trips = b.Trips,
                TotalCycleTime = (int)Math.Round(effectiveCycle),
            })
            .ToList();

        return [.. result.Select(bs => bs.Serialize())];
    }

    private static List<DepartureEvent> BuildDepartureEvents(
        List<double> gridA,
        List<double> gridB,
        double endMinutes
    )
    {
        var events = new List<DepartureEvent>(gridA.Count + gridB.Count);

        foreach (var t in gridA)
        {
            if (t >= endMinutes)
                break;
            events.Add(new DepartureEvent(t, terminalId: 0, routeId: 0));
        }

        foreach (var t in gridB)
        {
            if (t >= endMinutes)
                break;
            events.Add(new DepartureEvent(t, terminalId: 1, routeId: 1));
        }

        events.Sort(
            (a, b) =>
            {
                var cmp = a.Time.CompareTo(b.Time);
                if (cmp != 0)
                    return cmp;
                cmp = a.TerminalId.CompareTo(b.TerminalId);
                if (cmp != 0)
                    return cmp;
                return a.RouteId.CompareTo(b.RouteId);
            }
        );

        return events;
    }

    private static List<BrigadeState> InitializeBrigades(
        int numBrigades,
        double startMinutes,
        int minInitialAtA,
        int minInitialAtB
    )
    {
        var brigades = new List<BrigadeState>(numBrigades);

        var seedTerminalIds = new List<int>(numBrigades);
        for (int i = 0; i < minInitialAtA; i++)
            seedTerminalIds.Add(0);
        for (int i = 0; i < minInitialAtB; i++)
            seedTerminalIds.Add(1);

        int remainder = numBrigades - seedTerminalIds.Count;
        for (int i = 0; i < remainder; i++)
            seedTerminalIds.Add(i % 2 == 0 ? 0 : 1);

        for (int brigadeId = 0; brigadeId < numBrigades; brigadeId++)
        {
            brigades.Add(
                new BrigadeState
                {
                    BrigadeId = brigadeId,
                    TerminalId = seedTerminalIds[brigadeId],
                    AvailableAt = startMinutes,
                }
            );
        }
        return brigades;
    }

    private static void AssignDeparturesToBrigades(
        List<DepartureEvent> events,
        List<BrigadeState> brigades,
        System.Collections.Generic.Dictionary<int, int> forwardStopTimes,
        System.Collections.Generic.Dictionary<int, int> returnStopTimes,
        double forwardDuration,
        double returnDuration,
        double minLayoverMinutes
    )
    {
        foreach (var ev in events)
        {
            BrigadeState? selected = null;

            for (int i = 0; i < brigades.Count; i++)
            {
                var candidate = brigades[i];
                if (candidate.TerminalId != ev.TerminalId)
                    continue;
                if (candidate.AvailableAt > ev.Time)
                    continue;

                if (selected == null)
                {
                    selected = candidate;
                    continue;
                }

                if (candidate.AvailableAt < selected.AvailableAt)
                    selected = candidate;
                else if (
                    Math.Abs(candidate.AvailableAt - selected.AvailableAt) < 1e-9
                    && candidate.BrigadeId < selected.BrigadeId
                )
                    selected = candidate;
            }

            if (selected == null)
            {
                var terminalName = ev.TerminalId == 0 ? "A" : "B";
                throw new ArgumentException(
                    $"Strict headway infeasible during assignment: no brigade available for "
                        + $"terminal {terminalName} at t={ev.Time:F1} min. "
                        + $"Try increasing headway or reducing layover/travel times."
                );
            }

            if (ev.RouteId == 0)
            {
                selected.Trips.Add(CreateTrip(0, ev.Time, forwardStopTimes, forwardDuration));
                selected.TerminalId = 1;
                selected.AvailableAt = ev.Time + forwardDuration + minLayoverMinutes;
            }
            else
            {
                selected.Trips.Add(CreateTrip(1, ev.Time, returnStopTimes, returnDuration));
                selected.TerminalId = 0;
                selected.AvailableAt = ev.Time + returnDuration + minLayoverMinutes;
            }
        }
    }

    private static List<double> BuildDepartureGrid(double startMin, double endMin, double headway)
    {
        var grid = new List<double>();

        double t = startMin;

        while (t <= endMin)
        {
            grid.Add(t);
            t += headway;
        }
        return grid;
    }

    private static Trip CreateTrip(
        int routeId,
        double minutes,
        System.Collections.Generic.Dictionary<int, int> stopTimes,
        double duration
    )
    {
        var departTime = new TimeOfDay((int)minutes);

        return new Trip
        {
            RouteId = routeId,
            DepartureTime = departTime,
            ArrivalTime = new TimeOfDay((int)(minutes + duration)),
            StopTimes = stopTimes
                .Select(kvp => new KeyValuePair<int, TimeOfDay>(
                    kvp.Key,
                    departTime.AddMinutes(kvp.Value)
                ))
                .ToDictionary(kvp => kvp.Key, kvp => kvp.Value),
            Duration = duration,
        };
    }

    private System.Collections.Generic.Dictionary<int, int> GenerateStopTimes(List<TripStep> route)
    {
        var stopTimes = new System.Collections.Generic.Dictionary<int, int>();
        int cumulativeTime = 0;

        foreach (var step in route)
        {
            cumulativeTime += step.TravelTime;
            stopTimes[step.StepId] = cumulativeTime;
        }
        return stopTimes;
    }
}
