# Smart Medical Appointment & Medicine Inventory System
A database management project that helps hospitals handle patient appointments, medicine stock, billing, and doctor scheduling efficiently.

---

## 📌 Project Features
✔ Patient Registration  
✔ Doctor Information Management  
✔ Appointment Booking & Status Tracking  
✔ Medicine Stock Inventory  
✔ Billing System  
✔ Reporting Views & Data Analysis  


---
sql_project.sql

This SQL file contains:
- Full DDL (tables + constraints)
- Sample data inserts
- Views for reporting
- Useful analytics queries

---

## 📌 Project Overview

This system supports:

### ✔ Patient Management  
Store and retrieve patient demographic details.

### ✔ Doctor Management  
Track specialization, working hours, and availability.

### ✔ Appointment Scheduling  
Schedule, update, cancel, and view appointments.

### ✔ Medicine Inventory  
Manage stock, brands, expiry dates, and quantity.

### ✔ Prescription Handling  
Link appointments with medicines prescribed.

### ✔ Billing System  
Store invoice amounts and payment status.

---

## 🛠 Tools Used

| Tool | Purpose |
|------|---------|
| PostgreSQL / MySQL | Database backend |
| pgAdmin 4 / MySQL Workbench | SQL execution & ERD visualization |
| SQL | Core project logic |

---

## 📂 Project Files

Only *one master file* is used:

### 📄 sql_project.sql
Contains:
- Create database  
- Create tables  
- Insert sample data  
- Create views  
- Reporting queries  

Run this file directly in pgAdmin / Workbench.

---

## ▶ How to Run This Project

### *Step 1 — Create Database*
```sql
CREATE DATABASE smart_medical;

Step 2 — Open Query Tool

Right-click on the database → Query Tool.

Step 3 — Load the SQL File

Open → select sql_project.sql.

Step 4 — Execute

Click ▶ or press F5.

After execution:

All tables will be created

Data will be inserted

Views will be generated



---

🗂 Database Modules & Tables

Module	    |   Table
_______________________
Patients   	   patients
Doctors	       doctors
Appointments	 appointments
Prescriptions	 prescriptions
Medicines      	medicines
Billing       	billings


Each table includes:

Primary keys

Foreign keys

Data validation constraints

Indexes for performance



---


📜 Key Views Included

✔ Upcoming Appointments View

SELECT * FROM v_upcoming_appointments;

✔ Medicine Stock View

SELECT * FROM v_medicine_stock;

✔ Pending Bills View

SELECT * FROM v_pending_bills;


---

📈 Sample Reporting Queries

1. List all appointments for a specific doctor

SELECT a.*, p.full_name AS patient
FROM appointments a
JOIN patients p ON a.patient_id = p.patient_id
WHERE a.doctor_id = 2;

2. Medicines expiring in next 30 days

SELECT * FROM medicines
WHERE expiry_date <= CURRENT_DATE + INTERVAL '30 days';

3. Patients with unpaid bills

SELECT * FROM billings WHERE payment_status = 'Pending';


---




## 📚 Author
*Marapureddi Satya Durga Lakshmi*  
Email: marapureddisatyadurgalakshmi@gmail.com 
LinkedIn: https://www.linkedin.com/in/satya-durga-lakshmi-marapureddi  

---

⭐ If you like this project, consider giving it a star!
