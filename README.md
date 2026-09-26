# Hospital Management System – SQL Developer Inter
## 1. Project Overview

This project implements a small Hospital Management System using MySQL.

The solution demonstrates:

- Relational database design
- Primary and foreign keys
- Constraints and validation
- Sample data
- Stored procedures
- JOINs
- Aggregate functions
- Transactions
- Error handling
- Business-rule validation
- Appointment booking
- Billing
- Patient history
- Doctor performance reporting
- Monthly hospital reporting

## 2. Project Files

```text
hospital-management-sql/
│
├── database.sql
├── procedures.sql
└── README.md
```

### `database.sql`

Creates the `hospital_management` database and these tables:

1. `patients`
2. `doctors`
3. `appointments`
4. `bills`

It also inserts the required sample records:

- 10 patients
- 5 doctors
- 15 appointments
- 10 bills

### `procedures.sql`

Contains all six required stored procedures plus the bonus monthly report:

1. `RegisterPatient`
2. `GetDoctorAvailability`
3. `BookAppointment`
4. `CompleteAppointment`
5. `GetPatientHistory`
6. `GetDoctorPerformanceReport`
7. `GenerateMonthlyHospitalReport` – Bonus

## 3. Requirements

Install any MySQL 8.x compatible environment, for example:

- MySQL Server 8.x
- MySQL Workbench 8.x

## 4. Database Setup

Open MySQL Workbench and execute `database.sql` first.

The script will:

1. Remove an existing `hospital_management` database if present.
2. Create a fresh `hospital_management` database.
3. Create all four tables.
4. Add primary keys, foreign keys, unique constraints and checks.
5. Insert sample data.
6. Create useful indexes.

Then execute `procedures.sql`.

> Always execute `database.sql` before `procedures.sql`.

## 5. Verify Tables

Run:

```sql
USE hospital_management;

SHOW TABLES;
```

Expected tables:

```text
appointments
bills
doctors
patients
```

Check record counts:

```sql
SELECT COUNT(*) AS patient_count FROM patients;
SELECT COUNT(*) AS doctor_count FROM doctors;
SELECT COUNT(*) AS appointment_count FROM appointments;
SELECT COUNT(*) AS bill_count FROM bills;
```

Expected minimum counts:

```text
Patients      10
Doctors        5
Appointments  15
Bills         10
```

## 6. Stored Procedure Execution

### Procedure 1 – RegisterPatient

Registers a new patient and rejects duplicate phone numbers.

```sql
CALL RegisterPatient(
    'Rahul Mehta',
    '1998-05-12',
    'Male',
    '9876543210',
    'B+'
);
```

Expected output contains:

```text
patient_id
patient_name
status
message
```

To test duplicate validation, execute the same call again. The procedure should return an error because the phone number already exists.

---

### Procedure 2 – GetDoctorAvailability

Returns active doctors for a specialization and requested date.

```sql
CALL GetDoctorAvailability(
    'Cardiology',
    '2026-09-10'
);
```

Expected output:

```text
doctor_id
doctor_name
specialization
fee
```

The procedure uses the requested date to check existing scheduled appointments. Exact slot validation is performed by `BookAppointment`, because the required procedure input does not contain an appointment-time parameter.

---

### Procedure 3 – BookAppointment

Books an appointment after validating:

- Patient exists and is active
- Doctor exists
- Doctor is active
- Appointment date is valid
- Appointment time is supplied
- Doctor slot is not already booked

Example:

```sql
CALL BookAppointment(
    9,
    1,
    '2026-09-20',
    '10:30:00'
);
```

Expected output:

```text
appointment_id
booking_status
message
```

The procedure uses a transaction and rolls back if an SQL exception occurs.

---

### Procedure 4 – CompleteAppointment

Completes a scheduled appointment and creates a pending bill.

Example:

```sql
CALL CompleteAppointment(
    9,
    750.00,
    250.00
);
```

Total calculation:

```text
Total = Consultation Fee + Medicine Fee + Other Charges
```

Expected output:

```text
appointment_status
bill_id
total_amount
message
```

The procedure uses a transaction because both the bill creation and appointment update must succeed together.

---

### Procedure 5 – GetPatientHistory

Returns appointment and billing history for a patient.

```sql
CALL GetPatientHistory(1);
```

The result includes:

- Appointment date
- Appointment time
- Doctor
- Specialization
- Appointment status
- Bill amount
- Payment status

Records are shown newest first.

---

### Procedure 6 – GetDoctorPerformanceReport

Generates performance statistics for a doctor within a date range.

```sql
CALL GetDoctorPerformanceReport(
    1,
    '2026-09-01',
    '2026-09-30'
);
```

Output includes:

- Doctor name
- Completed appointments
- Total revenue
- Average bill

If no completed records exist in the period, the procedure returns zero revenue and zero average bill rather than NULL.

---

## 7. Bonus – Monthly Hospital Report

Execute:

```sql
CALL GenerateMonthlyHospitalReport(
    9,
    2026
);
```

The report returns:

- Total appointments
- Completed appointments
- Cancelled appointments
- Billed revenue
- Active-patient count

## 8. Important Business Rules

### Patient Registration

- Phone number must be unique.
- New patients are automatically set to `Active`.
- Invalid DOB is rejected.

### Doctor Availability

- Only active doctors are returned.
- Specialization is matched without case sensitivity.
- Existing scheduled appointments are considered for the requested date.

### Appointment Booking

- Patient must exist and be active.
- Doctor must exist and be active.
- Past appointment dates are rejected.
- Duplicate doctor/date/time slots are rejected.
- Appointment is inserted as `Scheduled`.

### Appointment Completion

- Only `Scheduled` appointments can be completed.
- Medicine and other charges cannot be negative.
- Bill is created as `Pending`.
- Appointment becomes `Completed`.
- Bill and appointment update are handled inside a transaction.

### Patient History

- Uses `patients`, `doctors`, `appointments` and `bills`.
- Uses a `LEFT JOIN` for bills so an appointment can still appear when it has no bill.

### Doctor Performance

- Counts only completed appointments.
- Calculates revenue from completed appointments with bills.
- Calculates average bill.
- Handles periods with no completed records.

## 9. Database Relationship

```text
PATIENTS
   |
   | 1
   |-------------------<
   |                   |
APPOINTMENTS           |
   |                   |
   | >-----------------|
   |
   | 1
   |
BILLS

DOCTORS
   |
   | 1
   |
   |-------------------<
        APPOINTMENTS


 10. Recommended Demo Flow

For a 2–5 minute interview demo, show the following:

### Step 1 – Database

```sql
USE hospital_management;

SELECT * FROM patients;
SELECT * FROM doctors;
SELECT * FROM appointments;
SELECT * FROM bills;
```

### Step 2 – Register Patient

```sql
CALL RegisterPatient(
    'Demo Patient',
    '2001-01-15',
    'Male',
    '9876543211',
    'A+'
);
```

### Step 3 – Doctor Availability

```sql
CALL GetDoctorAvailability(
    'Cardiology',
    '2026-09-20'
);
```

### Step 4 – Book Appointment

```sql
CALL BookAppointment(
    11,
    1,
    '2026-09-20',
    '10:30:00'
);
```

Use the returned appointment ID in the next step.

### Step 5 – Complete Appointment

```sql
CALL CompleteAppointment(
    <appointment_id>,
    750.00,
    250.00
);
```

### Step 6 – Patient History

```sql
CALL GetPatientHistory(11);
```

### Step 7 – Doctor Performance

```sql
CALL GetDoctorPerformanceReport(
    1,
    '2026-09-01',
    '2026-09-30'
);
```

### Step 8 – Bonus Report

```sql
CALL GenerateMonthlyHospitalReport(
    9,
    2026
);
```

## 11. GitHub Upload

Create a GitHub repository, for example:

```text
hospital-management-sql
```

Upload these three files:

```text
database.sql
procedures.sql
README.md
```

Recommended repository structure:

```text
hospital-management-sql/
├── database.sql
├── procedures.sql
└── README.md
```

After uploading, copy the GitHub repository URL for submission.

## 12. Submission Checklist

Before submitting, verify:

- [x] `database.sql`
- [x] `procedures.sql`
- [x] `README.md`
- [x] 10+ patients
- [x] 5+ doctors
- [x] 15+ appointments
- [x] 10+ bills

## 13. Submission

Submit:

1. GitHub repository link
The assignment specifies submission to:

`careers@jforcesolutions.com`

