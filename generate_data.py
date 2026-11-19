import random
from datetime import datetime, timedelta

random.seed(42)

airports = [
    ("DEL", "Indira Gandhi International", "New Delhi", "METRO_HUB"),
    ("BOM", "Chhatrapati Shivaji Maharaj Intl", "Mumbai", "METRO_HUB"),
    ("BLR", "Kempegowda International", "Bengaluru", "METRO_HUB"),
    ("HYD", "Rajiv Gandhi International", "Hyderabad", "METRO_HUB"),
    ("MAA", "Chennai International", "Chennai", "METRO_HUB"),
    ("CCU", "Netaji Subhas Chandra Bose Intl", "Kolkata", "REGIONAL"),
    ("PNQ", "Pune International", "Pune", "REGIONAL"),
    ("GOI", "Manohar International", "Goa", "REGIONAL"),
]

aircrafts = [
    (1, "Airbus A320neo", "Airbus", 180),
    (2, "Airbus A321neo", "Airbus", 220),
    (3, "Boeing 737-800", "Boeing", 186),
    (4, "Boeing 737 MAX 8", "Boeing", 192),
    (5, "ATR 72-600", "ATR", 72),
]

routes = [
    (1, "DEL", "BOM", 1148, 5200.00),
    (2, "BOM", "DEL", 1148, 5300.00),
    (3, "BLR", "DEL", 1740, 6400.00),
    (4, "DEL", "BLR", 1740, 6500.00),
    (5, "BOM", "BLR", 842, 4100.00),
    (6, "BLR", "BOM", 842, 4150.00),
    (7, "HYD", "DEL", 1253, 5400.00),
    (8, "MAA", "BLR", 290, 2900.00),
    (9, "DEL", "CCU", 1305, 5600.00),
    (10, "BOM", "GOI", 435, 3400.00),
]

first_names = ["Aarav", "Ananya", "Rohan", "Priya", "Vikram", "Neha", "Karthik", "Divya", "Siddharth", "Meera", "Arjun", "Kavya"]
last_names = ["Sharma", "Verma", "Nair", "Reddy", "Patel", "Iyer", "Menon", "Gupta", "Rao", "Kulkarni", "Das", "Joshi"]

lines = ["-- FlyRight Dataset (1,412 rows across 7 normalized tables)\nUSE flyright_db;\n"]

for code, name, city, tier in airports:
    lines.append(f"INSERT INTO airports VALUES ('{code}', '{name}', '{city}', '{tier}');")

for a_id, model, mfg, cap in aircrafts:
    lines.append(f"INSERT INTO aircraft (aircraft_id, model, manufacturer, total_capacity) VALUES ({a_id}, '{model}', '{mfg}', {cap});")

for r_id, orig, dest, dist, fare in routes:
    lines.append(f"INSERT INTO routes (route_id, origin_code, dest_code, distance_km, base_fare) VALUES ({r_id}, '{orig}', '{dest}', {dist}, {fare:.2f});")

tiers = ["SILVER", "SILVER", "GOLD", "PLATINUM"]
for i in range(1, 251):
    fn = random.choice(first_names)
    ln = random.choice(last_names)
    email = f"{fn.lower()}.{ln.lower()}{i}@flyrightmail.com"
    phone = f"+91-98{random.randint(10000000, 99999999)}"
    tier = random.choice(tiers)
    lines.append(f"INSERT INTO passengers (passenger_id, full_name, email, phone, loyalty_tier) VALUES ({i}, '{fn} {ln}', '{email}', '{phone}', '{tier}');")

base_start = datetime(2026, 1, 5, 6, 0)
dep_hours = [6, 8, 10, 13, 15, 18, 20, 21]
flights = []
for f_id in range(1, 121):
    route_id = random.randint(1, len(routes))
    aircraft_id = random.randint(1, len(aircrafts))
    day_offset = random.randint(0, 320)
    hour = random.choice(dep_hours)
    sched_dep = base_start + timedelta(days=day_offset, hours=(hour - 6))
    sched_arr = sched_dep + timedelta(hours=2, minutes=10)

    delay = random.choices([0, 5, 12, 22, 38, 55], weights=[35, 20, 18, 12, 10, 5])[0]
    if hour >= 18:
        delay += random.randint(12, 24)
    if sched_dep.month in (7, 8):
        delay += random.randint(14, 26)

    status = "DELAYED" if delay >= 15 else "LANDED"
    code = f"FR-{100 + f_id}"
    flights.append((f_id, route_id, sched_dep))
    lines.append(
        f"INSERT INTO flights (flight_id, flight_code, route_id, aircraft_id, sched_departure, sched_arrival, delay_minutes, flight_status) "
        f"VALUES ({f_id}, '{code}', {route_id}, {aircraft_id}, '{sched_dep:%Y-%m-%d %H:%M:%S}', '{sched_arr:%Y-%m-%d %H:%M:%S}', {delay}, '{status}');"
    )

seat_labels = ["1A", "2C", "10A", "12B", "14F", "18C", "21A", "24D"]
route_base_fare = {r[0]: r[4] for r in routes}
seat_id = 1
booking_id = 1

for f_id, r_id, sched_dep_dt in flights:
    chosen_seats = random.sample(seat_labels, 5)
    booked_set = set(chosen_seats[:random.randint(3, 4)])
    for s_no in chosen_seats:
        cabin = "BUSINESS" if s_no.startswith(("1", "2")) else "ECONOMY"
        lines.append(f"INSERT INTO seats (seat_id, flight_id, seat_no, cabin_class, is_booked) VALUES ({seat_id}, {f_id}, '{s_no}', '{cabin}', FALSE);")
        seat_id += 1

    for s_no in booked_set:
        p_id = random.randint(1, 250)
        lead_days = random.randint(1, 45)
        b_date = sched_dep_dt - timedelta(days=lead_days)
        base = route_base_fare[r_id]
        mult = 1.65 if s_no.startswith(("1", "2")) else (1.25 if lead_days < 7 else 0.95)
        fare = round(base * mult * random.uniform(0.95, 1.08), 2)
        b_status = random.choices(["CONFIRMED", "CANCELLED"], weights=[91, 9])[0]
        lines.append(
            f"INSERT INTO bookings (booking_id, flight_id, passenger_id, seat_no, booking_date, fare_paid, booking_status) "
            f"VALUES ({booking_id}, {f_id}, {p_id}, '{s_no}', '{b_date:%Y-%m-%d %H:%M:%S}', {fare:.2f}, '{b_status}');"
        )
        booking_id += 1

with open("data.sql", "w", encoding="utf-8") as f:
    f.write("\n".join(lines))

print(f"Generated data.sql successfully with {8 + 5 + 10 + 250 + 120 + (seat_id - 1) + (booking_id - 1)} total rows!")
