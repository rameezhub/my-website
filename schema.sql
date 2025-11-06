-- Run this file in your MySQL server to create the database, tables, procedures, triggers, and view.
CREATE DATABASE IF NOT EXISTS vehicle_rental_db;
USE vehicle_rental_db;

-- CUSTOMER
CREATE TABLE IF NOT EXISTS Customer (
    customer_id INT PRIMARY KEY AUTO_INCREMENT,
    first_name VARCHAR(50),
    last_name VARCHAR(50),
    address VARCHAR(100),
    city VARCHAR(50),
    state VARCHAR(50),
    phone VARCHAR(15),
    email VARCHAR(50) UNIQUE,
    license VARCHAR(30) UNIQUE
);

-- STAFF
CREATE TABLE IF NOT EXISTS Staff (
    staff_id INT PRIMARY KEY AUTO_INCREMENT,
    name VARCHAR(50),
    role VARCHAR(30),
    phone VARCHAR(15),
    email VARCHAR(50) UNIQUE
);

-- VEHICLE
CREATE TABLE IF NOT EXISTS Vehicle (
    vehicle_id INT PRIMARY KEY AUTO_INCREMENT,
    vehicle_type VARCHAR(50),
    registration_no VARCHAR(20) UNIQUE,
    rent_rate DECIMAL(10,2),
    status ENUM('Available','Reserved','Rented','Maintenance') DEFAULT 'Available'
);

-- RESERVATION
CREATE TABLE IF NOT EXISTS Reservation (
    reservation_id INT PRIMARY KEY AUTO_INCREMENT,
    customer_id INT,
    vehicle_id INT,
    start_date DATE,
    end_date DATE,
    status ENUM('Pending','Confirmed','Cancelled') DEFAULT 'Pending',
    FOREIGN KEY (customer_id) REFERENCES Customer(customer_id),
    FOREIGN KEY (vehicle_id) REFERENCES Vehicle(vehicle_id)
);

-- RENTAL
CREATE TABLE IF NOT EXISTS Rental (
    rental_id INT PRIMARY KEY AUTO_INCREMENT,
    reservation_id INT,
    staff_id INT,
    rental_date DATE,
    return_date DATE,
    total_amount DECIMAL(10,2),
    total_paid DECIMAL(10,2) DEFAULT 0,
    FOREIGN KEY (reservation_id) REFERENCES Reservation(reservation_id),
    FOREIGN KEY (staff_id) REFERENCES Staff(staff_id)
);

-- PAYMENT
CREATE TABLE IF NOT EXISTS Payment (
    payment_id INT PRIMARY KEY AUTO_INCREMENT,
    rental_id INT,
    payment_date DATE,
    amount DECIMAL(10,2),
    mode_of_payment ENUM('Cash','Card','Online'),
    FOREIGN KEY (rental_id) REFERENCES Rental(rental_id)
);

-- Stored Procedure: CreateReservation
DELIMITER $$
CREATE PROCEDURE IF NOT EXISTS CreateReservation(
    IN p_customer_id INT,
    IN p_vehicle_id INT,
    IN p_start_date DATE,
    IN p_end_date DATE
)
BEGIN
    DECLARE v_status VARCHAR(20);

    SELECT status INTO v_status FROM Vehicle WHERE vehicle_id = p_vehicle_id FOR UPDATE;

    IF v_status = 'Available' THEN
        INSERT INTO Reservation (customer_id, vehicle_id, start_date, end_date, status)
        VALUES (p_customer_id, p_vehicle_id, p_start_date, p_end_date, 'Confirmed');

        UPDATE Vehicle SET status = 'Reserved' WHERE vehicle_id = p_vehicle_id;
    ELSE
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Vehicle not available for reservation';
    END IF;
END $$
DELIMITER ;

-- Stored Procedure: GenerateRental
DELIMITER $$
CREATE PROCEDURE IF NOT EXISTS GenerateRental(
    IN p_reservation_id INT,
    IN p_staff_id INT
)
BEGIN
    DECLARE v_vehicle_id INT;
    DECLARE v_rate DECIMAL(10,2);
    DECLARE v_days INT;
    DECLARE v_total DECIMAL(10,2);
    DECLARE v_start DATE;
    DECLARE v_end DATE;

    SELECT vehicle_id, start_date, end_date INTO v_vehicle_id, v_start, v_end
    FROM Reservation
    WHERE reservation_id = p_reservation_id;

    SELECT rent_rate INTO v_rate FROM Vehicle WHERE vehicle_id = v_vehicle_id;

    SET v_days = DATEDIFF(v_end, v_start);
    IF v_days <= 0 THEN
      SET v_days = 1;
    END IF;
    SET v_total = v_days * v_rate;

    INSERT INTO Rental (reservation_id, staff_id, rental_date, return_date, total_amount)
    VALUES (p_reservation_id, p_staff_id, v_start, v_end, v_total);

    UPDATE Vehicle SET status = 'Rented' WHERE vehicle_id = v_vehicle_id;
END $$
DELIMITER ;

-- Trigger: AfterRentalUpdate (set vehicle available when return_date set)
DELIMITER $$
CREATE TRIGGER IF NOT EXISTS AfterRentalUpdate
AFTER UPDATE ON Rental
FOR EACH ROW
BEGIN
    DECLARE v_vehicle_id INT;
    SELECT vehicle_id INTO v_vehicle_id FROM Reservation WHERE reservation_id = NEW.reservation_id;
    IF NEW.return_date IS NOT NULL THEN
        UPDATE Vehicle SET status = 'Available' WHERE vehicle_id = v_vehicle_id;
    END IF;
END $$
DELIMITER ;

-- Trigger: AfterPaymentInsert (update total_paid in Rental)
DELIMITER $$
CREATE TRIGGER IF NOT EXISTS AfterPaymentInsert
AFTER INSERT ON Payment
FOR EACH ROW
BEGIN
    UPDATE Rental
    SET total_paid = total_paid + NEW.amount
    WHERE rental_id = NEW.rental_id;
END $$
DELIMITER ;

-- Rental Summary View
CREATE OR REPLACE VIEW RentalSummary AS
SELECT
    c.customer_id,
    CONCAT(c.first_name, ' ', c.last_name) AS customer_name,
    v.vehicle_type,
    v.registration_no,
    r.reservation_id,
    ren.rental_id,
    ren.rental_date,
    ren.return_date,
    ren.total_amount,
    IFNULL(ren.total_paid, 0) AS total_paid,
    (ren.total_amount - IFNULL(ren.total_paid, 0)) AS balance_due,
    p.payment_date,
    p.mode_of_payment,
    s.name AS staff_name
FROM Rental ren
JOIN Reservation r ON ren.reservation_id = r.reservation_id
JOIN Customer c ON r.customer_id = c.customer_id
JOIN Vehicle v ON r.vehicle_id = v.vehicle_id
LEFT JOIN Payment p ON ren.rental_id = p.rental_id
LEFT JOIN Staff s ON ren.staff_id = s.staff_id;
