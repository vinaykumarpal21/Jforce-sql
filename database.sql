-- ============================================================
-- JFORCE SOLUTIONS - HOSPITAL MANAGEMENT SYSTEM
-- File: database.sql
-- Database: MySQL 8.x
-- ============================================================

DROP DATABASE IF EXISTS hospital_management;
CREATE DATABASE hospital_management;
USE hospital_management;

-- ============================================================
-- 1. PATIENTS
-- ============================================================
CREATE TABLE patients (
    patient_id INT PRIMARY KEY AUTO_INCREMENT,
    patient_name VARCHAR(100) NOT NULL,
    date_of_birth DATE NOT NULL,
    gender VARCHAR(20) NOT NULL,
    phone VARCHAR(15) NOT NULL UNIQUE,
    blood_group VARCHAR(5),
    status VARCHAR(20) NOT NULL DEFAULT 'Active',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_patient_gender
        CHECK (gender IN ('Male', 'Female', 'Other')),
    CONSTRAINT chk_patient_status
        CHECK (status IN ('Active', 'Inactive')),
    CONSTRAINT chk_patient_blood_group
        CHECK (blood_group IN ('A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'))
);

-- ============================================================
-- 2. DOCTORS
-- ============================================================
CREATE TABLE doctors (
    doctor_id INT PRIMARY KEY AUTO_INCREMENT,
    doctor_name VARCHAR(100) NOT NULL,
    specialization VARCHAR(100) NOT NULL,
    consultation_fee DECIMAL(10,2) NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'Active',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_doctor_fee CHECK (consultation_fee >= 0),
    CONSTRAINT chk_doctor_status CHECK (status IN ('Active', 'Inactive'))
);

-- ============================================================
-- 3. APPOINTMENTS
-- ============================================================
CREATE TABLE appointments (
    appointment_id INT PRIMARY KEY AUTO_INCREMENT,
    patient_id INT NOT NULL,
    doctor_id INT NOT NULL,
    appointment_date DATE NOT NULL,
    appointment_time TIME NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'Scheduled',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_appointment_patient
        FOREIGN KEY (patient_id) REFERENCES patients(patient_id),

    CONSTRAINT fk_appointment_doctor
        FOREIGN KEY (doctor_id) REFERENCES doctors(doctor_id),

    CONSTRAINT chk_appointment_status
        CHECK (status IN ('Scheduled', 'Completed', 'Cancelled')),

    CONSTRAINT uq_doctor_slot
        UNIQUE (doctor_id, appointment_date, appointment_time)
);

-- ============================================================
-- 4. BILLS
-- ============================================================
CREATE TABLE bills (
    bill_id INT PRIMARY KEY AUTO_INCREMENT,
    patient_id INT NOT NULL,
    appointment_id INT NOT NULL UNIQUE,
    consultation_fee DECIMAL(10,2) NOT NULL,
    medicine_fee DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    other_charges DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    bill_date DATE NOT NULL,
    payment_status VARCHAR(20) NOT NULL DEFAULT 'Pending',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_bill_patient
        FOREIGN KEY (patient_id) REFERENCES patients(patient_id),

    CONSTRAINT fk_bill_appointment
        FOREIGN KEY (appointment_id) REFERENCES appointments(appointment_id),

    CONSTRAINT chk_bill_consultation_fee CHECK (consultation_fee >= 0),
    CONSTRAINT chk_bill_medicine_fee CHECK (medicine_fee >= 0),
    CONSTRAINT chk_bill_other_charges CHECK (other_charges >= 0),
    CONSTRAINT chk_bill_payment_status
        CHECK (payment_status IN ('Paid', 'Pending'))
);

-- ============================================================
-- SAMPLE DATA
-- ============================================================

-- 10 PATIENTS
INSERT INTO patients
(patient_name, date_of_birth, gender, phone, blood_group, status)
VALUES
('Amit Sharma',   '1995-03-12', 'Male',   '9876500001', 'B+',  'Active'),
('Priya Singh',   '1998-07-21', 'Female', '9876500002', 'O+',  'Active'),
('Rahul Mehta',   '1998-05-12', 'Male',   '9876500003', 'B+',  'Active'),
('Neha Verma',    '1992-11-08', 'Female', '9876500004', 'A+',  'Active'),
('Rohit Gupta',   '1989-01-17', 'Male',   '9876500005', 'O-',  'Active'),
('Anjali Yadav',  '2000-09-25', 'Female', '9876500006', 'AB+', 'Active'),
('Vikas Kumar',   '1985-04-14', 'Male',   '9876500007', 'A-',  'Active'),
('Sneha Patel',   '1996-12-03', 'Female', '9876500008', 'B-',  'Active'),
('Karan Malhotra','1990-06-19', 'Male',   '9876500009', 'AB-', 'Active'),
('Pooja Mishra',  '1999-02-28', 'Female', '9876500010', 'O+',  'Active');

-- 5 DOCTORS
INSERT INTO doctors
(doctor_name, specialization, consultation_fee, status)
VALUES
('Dr. Arjun Kapoor', 'Cardiology',    1200.00, 'Active'),
('Dr. Meera Joshi',  'Dermatology',    800.00, 'Active'),
('Dr. Raj Malhotra', 'Orthopedics',   1000.00, 'Active'),
('Dr. Kavita Rao',   'Pediatrics',     700.00, 'Active'),
('Dr. Sameer Khan',  'Neurology',     1500.00, 'Active');

-- 15 APPOINTMENTS
INSERT INTO appointments
(patient_id, doctor_id, appointment_date, appointment_time, status)
VALUES
(1, 1, '2026-09-01', '09:00:00', 'Completed'),
(2, 2, '2026-09-02', '10:00:00', 'Completed'),
(3, 3, '2026-09-03', '11:00:00', 'Completed'),
(4, 1, '2026-09-04', '09:30:00', 'Completed'),
(5, 4, '2026-09-05', '12:00:00', 'Completed'),
(6, 5, '2026-09-06', '14:00:00', 'Completed'),
(7, 2, '2026-09-07', '10:30:00', 'Completed'),
(8, 3, '2026-09-08', '11:30:00', 'Completed'),
(9, 1, '2026-09-09', '15:00:00', 'Scheduled'),
(10, 5, '2026-09-10', '16:00:00', 'Scheduled'),
(1, 2, '2026-09-11', '09:00:00', 'Cancelled'),
(2, 3, '2026-09-12', '10:00:00', 'Scheduled'),
(3, 4, '2026-09-13', '11:00:00', 'Completed'),
(4, 5, '2026-09-14', '13:00:00', 'Completed'),
(5, 1, '2026-09-15', '14:30:00', 'Scheduled');

-- 10 BILLS
INSERT INTO bills
(patient_id, appointment_id, consultation_fee, medicine_fee, other_charges, bill_date, payment_status)
VALUES
(1,  1, 1200.00,  500.00, 100.00, '2026-09-01', 'Paid'),
(2,  2,  800.00,  300.00,  50.00, '2026-09-02', 'Paid'),
(3,  3, 1000.00,  450.00, 100.00, '2026-09-03', 'Pending'),
(4,  4, 1200.00,  600.00, 150.00, '2026-09-04', 'Paid'),
(5,  5,  700.00,  250.00,  50.00, '2026-09-05', 'Paid'),
(6,  6, 1500.00,  700.00, 200.00, '2026-09-06', 'Pending'),
(7,  7,  800.00,  350.00,  75.00, '2026-09-07', 'Paid'),
(8,  8, 1000.00,  400.00, 100.00, '2026-09-08', 'Pending'),
(3, 13, 700.00,  200.00,  50.00, '2026-09-13', 'Paid'),
(4, 14, 1500.00, 500.00, 100.00, '2026-09-14', 'Pending');

-- Helpful indexes
CREATE INDEX idx_appointments_date
    ON appointments(appointment_date);

CREATE INDEX idx_appointments_doctor_date
    ON appointments(doctor_id, appointment_date);

CREATE INDEX idx_appointments_patient
    ON appointments(patient_id);

CREATE INDEX idx_bills_patient
    ON bills(patient_id);

CREATE INDEX idx_bills_date
    ON bills(bill_date);

-- Quick verification
SELECT 'Patients' AS table_name, COUNT(*) AS record_count FROM patients
UNION ALL
SELECT 'Doctors', COUNT(*) FROM doctors
UNION ALL
SELECT 'Appointments', COUNT(*) FROM appointments
UNION ALL
SELECT 'Bills', COUNT(*) FROM bills;
