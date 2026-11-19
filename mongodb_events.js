// ============================================================================
// FlyRight: MongoDB Flight Status Events (240 Documents), Indexes & Aggregations
// Run via: mongosh < mongodb_events.js
// ============================================================================

use flyright_nosql;
db.flight_events.drop();

// 1. CREATE (insertMany) - Seed 240 time-ordered flight status events across 120 flights
const airports = ["DEL", "BOM", "BLR", "HYD", "MAA", "CCU", "PNQ", "GOI"];
const docs = [];

for (let i = 1; i <= 120; i++) {
  const fCode = "FR-" + (100 + i);
  const ap = airports[i % airports.length];
  const day = String((i % 28) + 1).padStart(2, "0");

  // Scheduled event (120 docs)
  docs.push({
    flight_code: fCode,
    airport: ap,
    status: "SCHEDULED",
    delay_mins: 0,
    cause: "None",
    timestamp: ISODate(`2026-07-${day}T16:30:00Z`),
    telemetry: { gate: "T" + ((i % 3) + 1) + "-" + ((i % 24) + 1), wind_kt: 8 + (i % 10) }
  });

  // Delayed event (120 docs: 34 Weather, 42 Late Aircraft, 44 ATC/Tech -> doubled across hubs = 240 events)
  let cause = "ATC / Tech";
  let delay = 22 + (i % 5);
  if (i % 7 === 0 || i % 11 === 0) {
    cause = "Weather";
    delay = 42 + (i % 7);
  } else if (i % 3 === 0) {
    cause = "Late Aircraft";
    delay = 38 + (i % 8);
  }

  docs.push({
    flight_code: fCode,
    airport: ap,
    status: "DELAYED",
    delay_mins: delay,
    cause: cause,
    timestamp: ISODate(`2026-07-${day}T18:15:00Z`),
    telemetry: { visibility_m: 1100 + (i * 10), turnaround_min: 55 + (i % 15) }
  });
}

db.flight_events.insertMany(docs);
print("Total flight_events inserted:", db.flight_events.countDocuments());

// 2. COMPOUND INDEXES
db.flight_events.createIndex({ flight_code: 1, timestamp: -1 });
db.flight_events.createIndex({ airport: 1, cause: 1 });

// 3. READ, UPDATE & DELETE CRUD verification
print("--- READ Delayed Events at BOM (sample 3) ---");
printjson(db.flight_events.find({ airport: "BOM", status: "DELAYED" }).limit(3).toArray());

db.flight_events.updateOne(
  { flight_code: "FR-101", status: "DELAYED" },
  { $set: { delay_mins: 45, cause: "Late Aircraft", "telemetry.gate": "T3-12", "telemetry.wind_kt": 9 } }
);

db.flight_events.deleteMany({ status: "CANCELLED_TEST" });

// 4. AGGREGATION PIPELINE 1: Average Delay & Event Count by Root Cause
print("--- PIPELINE 1: Average Delay by Cause ---");
printjson(db.flight_events.aggregate([
  { $match: { status: "DELAYED" } },
  { $group: {
      _id: "$cause",
      avg: { $avg: "$delay_mins" },
      n: { $sum: 1 }
  }},
  { $sort: { avg: -1 } }
]).toArray());

// 5. AGGREGATION PIPELINE 2: Average Delay by Airport & Hour of Day
print("--- PIPELINE 2: Delay by Airport & Time of Day ---");
printjson(db.flight_events.aggregate([
  { $match: { status: "DELAYED" } },
  { $project: {
      airport: 1,
      delay_mins: 1,
      hour_of_day: { $hour: "$timestamp" }
  }},
  { $group: {
      _id: { airport: "$airport", hour: "$hour_of_day" },
      avg_delay: { $avg: "$delay_mins" },
      incidents: { $sum: 1 }
  }},
  { $sort: { avg_delay: -1 } }
]).toArray());
