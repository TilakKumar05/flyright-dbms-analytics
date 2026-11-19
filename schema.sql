-- ============================================================================
-- FlyRight: Airline Reservation & Flight Delay Analytics (Problem Statement 04)
-- Relational Database Schema (Normalised to 3NF)
-- ============================================================================

DROP DATABASE IF EXISTS flyright_db;
CREATE DATABASE flyright_db;
USE flyright_db;

-- 1. Airports Master Table
CREATE TABLE airports (
    airport_code CHAR(3) PRIMARY KEY,
    airport_name VARCHAR(100) NOT NULL,
    city VARCHAR(60) NOT NULL,
    hub_tier ENUM('METRO_HUB', 'REGIONAL') NOT NULL DEFAULT 'REGIONAL'
);

-- 2. Aircraft Fleet Table
CREATE TABLE aircraft (
    aircraft_id INT PRIMARY KEY AUTO_INCREMENT,
    model VARCHAR(50) NOT NULL,
    manufacturer VARCHAR(40) NOT NULL,
    total_capacity INT NOT NULL CHECK (total_capacity BETWEEN 50 AND 400)
);

-- 3. Routes Table (Decouples origin/destination metadata from flights)
CREATE TABLE routes (
    route_id INT PRIMARY KEY AUTO_INCREMENT,
    origin_code CHAR(3) NOT NULL,
    dest_code CHAR(3) NOT NULL,
    distance_km INT NOT NULL CHECK (distance_km > 0),
    base_fare DECIMAL(10, 2) NOT NULL CHECK (base_fare > 0),
    CONSTRAINT chk_different_airports CHECK (origin_code <> dest_code),
    CONSTRAINT uq_route_pair UNIQUE (origin_code, dest_code),
    CONSTRAINT fk_routes_origin FOREIGN KEY (origin_code) REFERENCES airports(airport_code),
    CONSTRAINT fk_routes_dest FOREIGN KEY (dest_code) REFERENCES airports(airport_code)
);

-- 4. Flights Schedule & Delay Fact Table
CREATE TABLE flights (
    flight_id INT PRIMARY KEY AUTO_INCREMENT,
    flight_code VARCHAR(10) NOT NULL,
    route_id INT NOT NULL,
    aircraft_id INT NOT NULL,
    sched_departure DATETIME NOT NULL,
    sched_arrival DATETIME NOT NULL,
    delay_minutes INT NOT NULL DEFAULT 0 CHECK (delay_minutes >= 0),
    flight_status ENUM('SCHEDULED', 'LANDED', 'DELAYED', 'CANCELLED') NOT NULL DEFAULT 'SCHEDULED',
    FOREIGN KEY (route_id) REFERENCES routes(route_id),
    FOREIGN KEY (aircraft_id) REFERENCES aircraft(aircraft_id)
);

-- 5. Passengers Table
CREATE TABLE passengers (
    passenger_id INT PRIMARY KEY AUTO_INCREMENT,
    full_name VARCHAR(100) NOT NULL,
    email VARCHAR(120) NOT NULL UNIQUE,
    phone VARCHAR(20) NOT NULL,
    loyalty_tier ENUM('SILVER', 'GOLD', 'PLATINUM') NOT NULL DEFAULT 'SILVER'
);

-- 6. Seat Inventory Table
CREATE TABLE seats (
    seat_id INT PRIMARY KEY AUTO_INCREMENT,
    flight_id INT NOT NULL,
    seat_no VARCHAR(5) NOT NULL,
    cabin_class ENUM('ECONOMY', 'BUSINESS') NOT NULL DEFAULT 'ECONOMY',
    is_booked BOOLEAN NOT NULL DEFAULT FALSE,
    CONSTRAINT uq_flight_seat UNIQUE (flight_id, seat_no),
    FOREIGN KEY (flight_id) REFERENCES flights(flight_id) ON DELETE CASCADE
);

-- 7. Bookings Table
CREATE TABLE bookings (
    booking_id INT PRIMARY KEY AUTO_INCREMENT,
    flight_id INT NOT NULL,
    passenger_id INT NOT NULL,
    seat_no VARCHAR(5) NOT NULL,
    booking_date DATETIME NOT NULL,
    fare_paid DECIMAL(10, 2) NOT NULL CHECK (fare_paid > 0),
    booking_status ENUM('CONFIRMED', 'CANCELLED') NOT NULL DEFAULT 'CONFIRMED',
    CONSTRAINT uq_active_booking_seat UNIQUE (flight_id, seat_no),
    FOREIGN KEY (flight_id) REFERENCES flights(flight_id),
    FOREIGN KEY (passenger_id) REFERENCES passengers(passenger_id)
);

-- ============================================================================
-- TRIGGER 1: Prevent Overbooking Beyond Aircraft Capacity
-- ============================================================================
DELIMITER //
CREATE TRIGGER trg_prevent_overbooking
BEFORE INSERT ON bookings
FOR EACH ROW
BEGIN
    DECLARE v_booked_count INT;
    DECLARE v_capacity INT;

    SELECT COUNT(*) INTO v_booked_count
    FROM bookings
    WHERE flight_id = NEW.flight_id
      AND booking_status = 'CONFIRMED';

    SELECT a.total_capacity INTO v_capacity
    FROM flights f
    JOIN aircraft a ON f.aircraft_id = a.aircraft_id
    WHERE f.flight_id = NEW.flight_id;

    IF NEW.booking_status = 'CONFIRMED' AND v_booked_count >= v_capacity THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'OVERBOOKING BLOCKED: Flight has reached maximum aircraft capacity.';
    END IF;
END //
DELIMITER ;

-- ============================================================================
-- TRIGGER 2: Sync Seat Inventory Status on Booking Confirmation
-- ============================================================================
DELIMITER //
CREATE TRIGGER trg_sync_seat_booked
AFTER INSERT ON bookings
FOR EACH ROW
BEGIN
    IF NEW.booking_status = 'CONFIRMED' THEN
        UPDATE seats
        SET is_booked = TRUE
        WHERE flight_id = NEW.flight_id AND seat_no = NEW.seat_no;
    END IF;
END //
DELIMITER ;

-- ============================================================================
-- VIEW: Route Occupancy & Revenue Summary View
-- ============================================================================
CREATE VIEW vw_route_revenue AS
SELECT
    r.route_id,
    CONCAT(r.origin_code, ' -> ', r.dest_code) AS route_name,
    r.origin_code,
    r.dest_code,
    COUNT(DISTINCT f.flight_id) AS total_flights,
    COUNT(b.booking_id) AS confirmed_bookings,
    ROUND(SUM(COALESCE(b.fare_paid, 0)), 2) AS total_revenue,
    ROUND(AVG(f.delay_minutes), 1) AS avg_delay_mins
FROM routes r
LEFT JOIN flights f ON r.route_id = f.route_id
LEFT JOIN bookings b ON f.flight_id = b.flight_id AND b.booking_status = 'CONFIRMED'
GROUP BY r.route_id, r.origin_code, r.dest_code;
