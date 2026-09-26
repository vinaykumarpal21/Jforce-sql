-- ============================================================
-- JFORCE SOLUTIONS - HOSPITAL MANAGEMENT SYSTEM

USE hospital_management;

DELIMITER $$

-- PROCEDURE 1: RegisterPatient
    
DROP PROCEDURE IF EXISTS RegisterPatient$$

CREATE PROCEDURE RegisterPatient(
    IN p_patient_name VARCHAR(100),
    IN p_date_of_birth DATE,
    IN p_gender VARCHAR(20),
    IN p_phone VARCHAR(15),
    IN p_blood_group VARCHAR(5)
)
BEGIN
    DECLARE v_patient_id INT DEFAULT NULL;

    -- Basic validation
    IF p_patient_name IS NULL OR TRIM(p_patient_name) = '' THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Patient name is required';
    END IF;

    IF p_date_of_birth IS NULL OR p_date_of_birth > CURDATE() THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Invalid date of birth';
    END IF;

    IF p_phone IS NULL OR TRIM(p_phone) = '' THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Phone number is required';
    END IF;

    -- Duplicate phone validation
    SELECT patient_id
    INTO v_patient_id
    FROM patients
    WHERE phone = p_phone
    LIMIT 1;

    IF v_patient_id IS NOT NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Duplicate phone number: patient already exists';
    END IF;

    INSERT INTO patients
    (patient_name, date_of_birth, gender, phone, blood_group, status)
    VALUES
    (TRIM(p_patient_name), p_date_of_birth, p_gender, p_phone, p_blood_group, 'Active');

    SET v_patient_id = LAST_INSERT_ID();

    SELECT
        v_patient_id AS patient_id,
        patient_name,
        status,
        'Patient registered successfully' AS message
    FROM patients
    WHERE patient_id = v_patient_id;
END$$


-- ============================================================
-- PROCEDURE 2: GetDoctorAvailability
-- ============================================================
DROP PROCEDURE IF EXISTS GetDoctorAvailability$$

CREATE PROCEDURE GetDoctorAvailability(
    IN p_specialization VARCHAR(100),
    IN p_appointment_date DATE
)
BEGIN
    IF p_specialization IS NULL OR TRIM(p_specialization) = '' THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Specialization is required';
    END IF;

    IF p_appointment_date IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Appointment date is required';
    END IF;

    /*
      The task specifies specialization + date as inputs.
      Since no appointment_time parameter is supplied, this procedure
      returns active doctors of that specialization who have not been
      cancelled/excluded for the requested date.

      Actual slot-level conflict is validated by BookAppointment.
    */
    SELECT
        d.doctor_id,
        d.doctor_name,
        d.specialization,
        d.consultation_fee AS fee
    FROM doctors d
    WHERE d.status = 'Active'
      AND LOWER(d.specialization) = LOWER(TRIM(p_specialization))
      AND NOT EXISTS (
          SELECT 1
          FROM appointments a
          WHERE a.doctor_id = d.doctor_id
            AND a.appointment_date = p_appointment_date
            AND a.status = 'Scheduled'
      )
    ORDER BY d.doctor_id;
END$$



-- PROCEDURE 3: BookAppointment


CREATE PROCEDURE BookAppointment(
    IN p_patient_id INT,
    IN p_doctor_id INT,
    IN p_appointment_date DATE,
    IN p_appointment_time TIME
)
BEGIN
    DECLARE v_patient_exists INT DEFAULT 0;
    DECLARE v_doctor_exists INT DEFAULT 0;
    DECLARE v_doctor_status VARCHAR(20);
    DECLARE v_slot_exists INT DEFAULT 0;
    DECLARE v_appointment_id INT DEFAULT NULL;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;

    -- Validate patient
    SELECT COUNT(*)
    INTO v_patient_exists
    FROM patients
    WHERE patient_id = p_patient_id
      AND status = 'Active';

    IF v_patient_exists = 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Invalid or inactive patient';
    END IF;

    -- Validate doctor
    SELECT COUNT(*), MAX(status)
    INTO v_doctor_exists, v_doctor_status
    FROM doctors
    WHERE doctor_id = p_doctor_id;

    IF v_doctor_exists = 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Doctor not found';
    END IF;

    IF v_doctor_status <> 'Active' THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Doctor is inactive';
    END IF;

    IF p_appointment_date IS NULL OR p_appointment_date < CURDATE() THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Appointment date cannot be in the past';
    END IF;

    IF p_appointment_time IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Appointment time is required';
    END IF;

    -- Prevent duplicate doctor slot
    SELECT COUNT(*)
    INTO v_slot_exists
    FROM appointments
    WHERE doctor_id = p_doctor_id
      AND appointment_date = p_appointment_date
      AND appointment_time = p_appointment_time
      AND status = 'Scheduled';

    IF v_slot_exists > 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Doctor slot is already booked';
    END IF;

    INSERT INTO appointments
    (patient_id, doctor_id, appointment_date, appointment_time, status)
    VALUES
    (p_patient_id, p_doctor_id, p_appointment_date, p_appointment_time, 'Scheduled');

    SET v_appointment_id = LAST_INSERT_ID();

    COMMIT;

    SELECT
        v_appointment_id AS appointment_id,
        'Scheduled' AS booking_status,
        'Appointment booked successfully' AS message;
END$$



-- PROCEDURE 4: CompleteAppointment

DROP PROCEDURE IF EXISTS CompleteAppointment$$

CREATE PROCEDURE CompleteAppointment(
    IN p_appointment_id INT,
    IN p_medicine_fee DECIMAL(10,2),
    IN p_other_charges DECIMAL(10,2)
)
BEGIN
    DECLARE v_status VARCHAR(20);
    DECLARE v_patient_id INT;
    DECLARE v_consultation_fee DECIMAL(10,2);
    DECLARE v_bill_id INT;
    DECLARE v_total DECIMAL(10,2);

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;

    IF p_medicine_fee IS NULL OR p_medicine_fee < 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Medicine fee cannot be negative';
    END IF;

    IF p_other_charges IS NULL OR p_other_charges < 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Other charges cannot be negative';
    END IF;

    -- Get appointment and doctor fee
    SELECT
        a.status,
        a.patient_id,
        d.consultation_fee
    INTO
        v_status,
        v_patient_id,
        v_consultation_fee
    FROM appointments a
    INNER JOIN doctors d
        ON d.doctor_id = a.doctor_id
    WHERE a.appointment_id = p_appointment_id
    FOR UPDATE;

    IF v_status IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Appointment not found';
    END IF;

    IF v_status <> 'Scheduled' THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Only Scheduled appointments can be completed';
    END IF;

    SET v_total = v_consultation_fee + p_medicine_fee + p_other_charges;

    -- Create pending bill
    INSERT INTO bills
    (
        patient_id,
        appointment_id,
        consultation_fee,
        medicine_fee,
        other_charges,
        bill_date,
        payment_status
    )
    VALUES
    (
        v_patient_id,
        p_appointment_id,
        v_consultation_fee,
        p_medicine_fee,
        p_other_charges,
        CURDATE(),
        'Pending'
    );

    SET v_bill_id = LAST_INSERT_ID();

    -- Mark appointment completed
    UPDATE appointments
    SET status = 'Completed'
    WHERE appointment_id = p_appointment_id;

    COMMIT;

    SELECT
        'Completed' AS appointment_status,
        v_bill_id AS bill_id,
        v_total AS total_amount,
        'Appointment completed and bill created' AS message;
END$$



-- PROCEDURE 5: GetPatientHistory

DROP PROCEDURE IF EXISTS GetPatientHistory$$

CREATE PROCEDURE GetPatientHistory(
    IN p_patient_id INT
)
BEGIN
    DECLARE v_patient_exists INT DEFAULT 0;

    SELECT COUNT(*)
    INTO v_patient_exists
    FROM patients
    WHERE patient_id = p_patient_id;

    IF v_patient_exists = 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Patient not found';
    END IF;

    SELECT
        a.appointment_date AS appointment_date,
        a.appointment_time AS appointment_time,
        d.doctor_name,
        d.specialization,
        a.status AS appointment_status,
        COALESCE(
            b.consultation_fee + b.medicine_fee + b.other_charges,
            0.00
        ) AS bill_amount,
        COALESCE(b.payment_status, 'Not Billed') AS payment_status
    FROM appointments a
    INNER JOIN patients p
        ON p.patient_id = a.patient_id
    INNER JOIN doctors d
        ON d.doctor_id = a.doctor_id
    LEFT JOIN bills b
        ON b.appointment_id = a.appointment_id
    WHERE a.patient_id = p_patient_id
    ORDER BY a.appointment_date DESC, a.appointment_time DESC;
END$$


-- PROCEDURE 6: GetDoctorPerformanceReport

DROP PROCEDURE IF EXISTS GetDoctorPerformanceReport$$

CREATE PROCEDURE GetDoctorPerformanceReport(
    IN p_doctor_id INT,
    IN p_start_date DATE,
    IN p_end_date DATE
)
BEGIN
    DECLARE v_doctor_exists INT DEFAULT 0;

    IF p_start_date IS NULL OR p_end_date IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Start date and end date are required';
    END IF;

    IF p_start_date > p_end_date THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Start date cannot be after end date';
    END IF;

    SELECT COUNT(*)
    INTO v_doctor_exists
    FROM doctors
    WHERE doctor_id = p_doctor_id;

    IF v_doctor_exists = 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Doctor not found';
    END IF;

    SELECT
        d.doctor_name,
        COUNT(CASE WHEN a.status = 'Completed' THEN 1 END)
            AS completed_appointments,
        COALESCE(
            SUM(
                CASE
                    WHEN a.status = 'Completed' AND b.bill_id IS NOT NULL
                    THEN b.consultation_fee + b.medicine_fee + b.other_charges
                    ELSE 0
                END
            ),
            0.00
        ) AS total_revenue,
        COALESCE(
            AVG(
                CASE
                    WHEN a.status = 'Completed' AND b.bill_id IS NOT NULL
                    THEN b.consultation_fee + b.medicine_fee + b.other_charges
                END
            ),
            0.00
        ) AS average_bill
    FROM doctors d
    LEFT JOIN appointments a
        ON a.doctor_id = d.doctor_id
       AND a.appointment_date BETWEEN p_start_date AND p_end_date
    LEFT JOIN bills b
        ON b.appointment_id = a.appointment_id
    WHERE d.doctor_id = p_doctor_id
    GROUP BY d.doctor_id, d.doctor_name;
END$$


-- BONUS: GenerateMonthlyHospitalReport

DROP PROCEDURE IF EXISTS GenerateMonthlyHospitalReport$$

CREATE PROCEDURE GenerateMonthlyHospitalReport(
    IN p_month INT,
    IN p_year INT
)
BEGIN
    DECLARE v_start_date DATE;
    DECLARE v_end_date DATE;

    IF p_month IS NULL OR p_month NOT BETWEEN 1 AND 12 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Month must be between 1 and 12';
    END IF;

    IF p_year IS NULL OR p_year < 2000 OR p_year > 2100 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Invalid year';
    END IF;

    SET v_start_date = STR_TO_DATE(
        CONCAT(p_year, '-', LPAD(p_month, 2, '0'), '-01'),
        '%Y-%m-%d'
    );

    SET v_end_date = LAST_DAY(v_start_date);

    SELECT
        p_month AS report_month,
        p_year AS report_year,
        (
            SELECT COUNT(*)
            FROM appointments
            WHERE appointment_date BETWEEN v_start_date AND v_end_date
        ) AS total_appointments,
        (
            SELECT COUNT(*)
            FROM appointments
            WHERE appointment_date BETWEEN v_start_date AND v_end_date
              AND status = 'Completed'
        ) AS completed_appointments,
        (
            SELECT COUNT(*)
            FROM appointments
            WHERE appointment_date BETWEEN v_start_date AND v_end_date
              AND status = 'Cancelled'
        ) AS cancelled_appointments,
        (
            SELECT COALESCE(
                SUM(consultation_fee + medicine_fee + other_charges),
                0.00
            )
            FROM bills
            WHERE bill_date BETWEEN v_start_date AND v_end_date
        ) AS billed_revenue,
        (
            SELECT COUNT(*)
            FROM patients
            WHERE status = 'Active'
        ) AS active_patient_count;
END$$

DELIMITER ;

