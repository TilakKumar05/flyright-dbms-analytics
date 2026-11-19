-- ============================================================================
-- FlyRight: Analytical SQL Queries & Trigger Demonstration
-- ============================================================================
USE flyright_db;

-- Q1: Seat Occupancy Rate per Flight
SELECT
    f.flight_code,
    CONCAT(r.origin_code, ' -> ', r.dest_code) AS route,
    a.model AS aircraft_model,
    COUNT(b.booking_id) AS confirmed_seats,
    a.total_capacity,
    ROUND((COUNT(b.booking_id) / a.total_capacity) * 100, 2) AS occupancy_pct
FROM flights f
JOIN routes r ON f.route_id = r.route_id
JOIN aircraft a ON f.aircraft_id = a.aircraft_id
LEFT JOIN bookings b ON f.flight_id = b.flight_id AND b.booking_status = 'CONFIRMED'
GROUP BY f.flight_id, f.flight_code, route, a.model, a.total_capacity
ORDER BY occupancy_pct DESC
LIMIT 10;

-- Q2: Total Revenue & Average Ticket Yield per Route (Using View)
SELECT
    route_name,
    total_flights,
    confirmed_bookings,
    total_revenue,
    ROUND(total_revenue / NULLIF(confirmed_bookings, 0), 2) AS avg_ticket_fare,
    avg_delay_mins
FROM vw_route_revenue
ORDER BY total_revenue DESC;

-- Q3: Most Delayed Routes and Departure Airports (Window Ranking)
SELECT
    r.origin_code AS departure_airport,
    CONCAT(r.origin_code, ' -> ', r.dest_code) AS route,
    COUNT(f.flight_id) AS operated_flights,
    ROUND(AVG(f.delay_minutes), 1) AS avg_delay_mins,
    RANK() OVER (ORDER BY AVG(f.delay_minutes) DESC) AS delay_rank
FROM flights f
JOIN routes r ON f.route_id = r.route_id
GROUP BY r.origin_code, route
HAVING COUNT(f.flight_id) >= 5;

-- Q4: Booking Lead Time vs. Average Fare Paid
SELECT
    CASE
        WHEN DATEDIFF(f.sched_departure, b.booking_date) >= 21 THEN '21+ Days Advance'
        WHEN DATEDIFF(f.sched_departure, b.booking_date) BETWEEN 7 AND 20 THEN '7-20 Days Advance'
        ELSE 'Last-Minute (<7 Days)'
    END AS lead_time_bucket,
    COUNT(b.booking_id) AS total_bookings,
    ROUND(AVG(b.fare_paid), 2) AS avg_fare_paid
FROM bookings b
JOIN flights f ON b.flight_id = f.flight_id
WHERE b.booking_status = 'CONFIRMED'
GROUP BY lead_time_bucket
ORDER BY avg_fare_paid ASC;

-- Q5: Live Demo Trigger Verification (Uncomment to test duplicate seat / capacity guard)
-- INSERT INTO bookings (flight_id, passenger_id, seat_no, booking_date, fare_paid, booking_status)
-- VALUES (1, 10, '1A', NOW(), 5500.00, 'CONFIRMED');
