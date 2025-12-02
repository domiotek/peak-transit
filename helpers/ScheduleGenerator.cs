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

        double naturalCycleMin = forwardDuration + returnDuration + minLayoverMinutes;
        int numBrigades = (int)Math.Ceiling(naturalCycleMin / headwayMinutes);

        double effectiveCycle = numBrigades * headwayMinutes;
        double requiredLayoverTotal = effectiveCycle - (forwardDuration + returnDuration);

        if (requiredLayoverTotal < minLayoverMinutes)
        {
            throw new ArgumentException(
                $"Strict headway infeasible with current parameters:\n"
                    + $"- Required total layover: {requiredLayoverTotal:F1} min\n"
                    + $"- Your minimum layover:  {minLayoverMinutes:F1} min\n\n"
                    + $"Fix by:\n"
                    + $"- Increasing frequency\n"
                    + $"- Reducing minimum layover"
            );
        }

        var gridA = BuildDepartureGrid(startMinutes, endMinutes, headwayMinutes);

        double gridBOffsetFromA = forwardDuration + minLayoverMinutes;
        var gridB = BuildDepartureGrid(startMinutes + gridBOffsetFromA, endMinutes, headwayMinutes);

        var gridBInitial = gridA;

        var forwardStopTimes = GenerateStopTimes(forwardRoute);
        var returnStopTimes = GenerateStopTimes(returnRoute);

        var result = new List<BrigadeSchedule>(numBrigades);
        for (int brigadeId = 0; brigadeId < numBrigades; brigadeId++)
        {
            bool startFromB = brigadeId % 2 == 1;

            var trips = GenerateBrigadeTrips(
                brigadeId,
                gridA,
                gridB,
                gridBInitial,
                forwardStopTimes,
                returnStopTimes,
                forwardDuration,
                returnDuration,
                minLayoverMinutes,
                endMinutes,
                startFromB
            );

            result.Add(
                new BrigadeSchedule
                {
                    BrigadeId = brigadeId,
                    Trips = trips,
                    TotalCycleTime = (int)Math.Round(effectiveCycle),
                }
            );
        }

        return [.. result.Select(bs => bs.Serialize())];
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

    private static List<Trip> GenerateBrigadeTrips(
        int brigadeId,
        List<double> gridA,
        List<double> gridB,
        List<double> gridBInitial,
        System.Collections.Generic.Dictionary<int, int> forwardStopTimes,
        System.Collections.Generic.Dictionary<int, int> returnStopTimes,
        double forwardDuration,
        double returnDuration,
        double minLayover,
        double endMinutes,
        bool startFromB
    )
    {
        var trips = new List<Trip>();

        int nextGridAIndex = brigadeId;
        int nextGridBIndex = brigadeId;

        if (startFromB)
        {
            if (gridBInitial.Count == 0)
                return trips;

            double firstBDeparture = gridBInitial[0];

            double currentTime = firstBDeparture;
            nextGridAIndex = brigadeId;
            while (currentTime < endMinutes)
            {
                double depB = currentTime;
                trips.Add(CreateTrip(1, depB, returnStopTimes, returnDuration));
                double arriveA = depB + returnDuration;

                double earliestDepA = arriveA + minLayover;
                double? depA = FindNextGridSlot(gridA, ref nextGridAIndex, earliestDepA);

                if (depA == null || depA >= endMinutes)
                    break;

                trips.Add(CreateTrip(0, depA.Value, forwardStopTimes, forwardDuration));
                double arriveB = depA.Value + forwardDuration;

                double earliestDepB = arriveB + minLayover;
                double? nextDepB = FindNextGridSlot(gridB, ref nextGridBIndex, earliestDepB);
                if (nextDepB == null || nextDepB >= endMinutes)
                    break;

                currentTime = nextDepB.Value;
            }
        }
        else
        {
            if (brigadeId >= gridA.Count)
                return trips;

            double currentTime = gridA[brigadeId];
            nextGridAIndex = brigadeId + 1;

            while (currentTime < endMinutes)
            {
                double depA = currentTime;
                trips.Add(CreateTrip(0, depA, forwardStopTimes, forwardDuration));
                double arriveB = depA + forwardDuration;

                double earliestDepB = arriveB + minLayover;
                double? depB = FindNextGridSlot(gridB, ref nextGridBIndex, earliestDepB);
                if (depB == null || depB >= endMinutes)
                    break;

                trips.Add(CreateTrip(1, depB.Value, returnStopTimes, returnDuration));
                double arriveA = depB.Value + returnDuration;

                double earliestDepA = arriveA + minLayover;
                double? nextDepA = FindNextGridSlot(gridA, ref nextGridAIndex, earliestDepA);
                if (nextDepA == null || nextDepA >= endMinutes)
                    break;

                currentTime = nextDepA.Value;
            }
        }

        return trips;
    }

    private static double? FindNextGridSlot(List<double> grid, ref int currentIndex, double minTime)
    {
        while (currentIndex < grid.Count && grid[currentIndex] < minTime)
        {
            currentIndex++;
        }

        if (currentIndex < grid.Count)
        {
            double slot = grid[currentIndex];
            currentIndex++;
            return slot;
        }

        return null;
    }

    private static Trip CreateTrip(
        int routeId,
        double minutes,
        System.Collections.Generic.Dictionary<int, int> stopTimes,
        double duration
    )
    {
        double departHour = Math.Floor(minutes / 60 % 24);
        double departMinute = Math.Floor(minutes % 60);

        double arriveHour = Math.Floor((minutes + duration) / 60 % 24);
        double arriveMinute = Math.Floor((minutes + duration) % 60);

        var departTime = new TimeOfDay { Hour = (int)departHour, Minute = (int)departMinute };

        return new Trip
        {
            RouteId = routeId,
            DepartureTime = departTime,
            ArrivalTime = new TimeOfDay { Hour = (int)arriveHour, Minute = (int)arriveMinute },
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
