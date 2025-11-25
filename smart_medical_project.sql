
-- \c smart_medical

-- 2. Schema creation (safe drops included)
DROP TABLE IF EXISTS billing CASCADE;
DROP TABLE IF EXISTS pharmacy_orders CASCADE;
DROP TABLE IF EXISTS medicines CASCADE;
DROP TABLE IF EXISTS appointments CASCADE;
DROP TABLE IF EXISTS doctors CASCADE;
DROP TABLE IF EXISTS patients CASCADE;
DROP TABLE IF EXISTS departments CASCADE;

-- Departments (optional)
CREATE TABLE departments (
  dept_id SERIAL PRIMARY KEY,
  dept_name TEXT NOT NULL UNIQUE
);

-- Patients
CREATE TABLE patients (
  patient_id SERIAL PRIMARY KEY,
  full_name TEXT NOT NULL,
  dob DATE,
  gender VARCHAR(10),
  phone VARCHAR(20) UNIQUE,
  email TEXT UNIQUE,
  address TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

-- Doctors
CREATE TABLE doctors (
  doctor_id SERIAL PRIMARY KEY,
  full_name TEXT NOT NULL,
  specialization TEXT,
  dept_id INT REFERENCES departments(dept_id) ON DELETE SET NULL,
  phone VARCHAR(20),
  email TEXT UNIQUE
);

-- Appointments
CREATE TABLE appointments (
  appointment_id SERIAL PRIMARY KEY,
  patient_id INT NOT NULL REFERENCES patients(patient_id) ON DELETE CASCADE,
  doctor_id INT REFERENCES doctors(doctor_id) ON DELETE SET NULL,
  appointment_date DATE NOT NULL,
  appointment_time TIME,
  status VARCHAR(20) DEFAULT 'Scheduled', -- Scheduled / Completed / Cancelled / No-Show
  reason TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  UNIQUE(patient_id, doctor_id, appointment_date, appointment_time) -- prevents duplicates
);

-- Medicines (inventory)
CREATE TABLE medicines (
  medicine_id SERIAL PRIMARY KEY,
  medicine_name TEXT NOT NULL,
  brand TEXT,
  batch_no TEXT,
  unit_price NUMERIC(10,2) DEFAULT 0.00,
  quantity INT DEFAULT 0 CHECK (quantity >= 0),
  expiry_date DATE
);

-- Pharmacy Orders (when a patient buys medicines)
CREATE TABLE pharmacy_orders (
  order_id SERIAL PRIMARY KEY,
  patient_id INT REFERENCES patients(patient_id) ON DELETE SET NULL,
  order_date TIMESTAMP WITH TIME ZONE DEFAULT now(),
  total_amount NUMERIC(12,2) DEFAULT 0.00,
  payment_status VARCHAR(20) DEFAULT 'Pending' -- Paid, Pending, COD
);

-- Pharmacy order items (many-to-one)
CREATE TABLE pharmacy_order_items (
  item_id SERIAL PRIMARY KEY,
  order_id INT REFERENCES pharmacy_orders(order_id) ON DELETE CASCADE,
  medicine_id INT REFERENCES medicines(medicine_id) ON DELETE SET NULL,
  quantity INT NOT NULL CHECK (quantity > 0),
  price_each NUMERIC(10,2) NOT NULL
);

-- Billing (link to appointment or pharmacy order)
CREATE TABLE billing (
  bill_id SERIAL PRIMARY KEY,
  patient_id INT REFERENCES patients(patient_id) ON DELETE SET NULL,
  appointment_id INT REFERENCES appointments(appointment_id) ON DELETE SET NULL,
  order_id INT REFERENCES pharmacy_orders(order_id) ON DELETE SET NULL,
  amount NUMERIC(12,2) NOT NULL,
  bill_date TIMESTAMP WITH TIME ZONE DEFAULT now(),
  paid BOOLEAN DEFAULT FALSE,
  payment_method VARCHAR(20)
);

-- Indexes for performance
CREATE INDEX idx_appointments_date ON appointments(appointment_date);
CREATE INDEX idx_medicines_name ON medicines(medicine_name);
CREATE INDEX idx_pharmacy_orders_patient ON pharmacy_orders(patient_id);

--3. departments
INSERT INTO departments(dept_name) VALUES ('Cardiology'), ('Dermatology'), ('General Medicine');

-- patients
INSERT INTO patients(full_name, dob, gender, phone, email, address)
VALUES
('Rohit Sharma','1990-05-12','Male','9876543210','rohit@example.com','Hyderabad'),
('Meena Kumari','1988-10-22','Female','8881234567','meena@example.com','Vijayawada'),
('Ananya Roy','2000-03-03','Female','7772345678','ananya.r@example.com','Guntur');

-- doctors
INSERT INTO doctors(full_name, specialization, dept_id, phone, email)
VALUES
('Dr. Arun Mehta','Cardiologist', 1,'9900111222','arun.mehta@hospital.com'),
('Dr. Neha Verma','Dermatologist', 2,'9900222333','neha.verma@hospital.com'),
('Dr. Santosh Rao','General Physician', 3,'9900333444','santosh.rao@hospital.com');

-- appointments
INSERT INTO appointments(patient_id, doctor_id, appointment_date, appointment_time, status, reason)
VALUES
(1,1,'2025-11-20','10:30:00','Scheduled','Chest pain'),
(2,2,'2025-11-21','11:00:00','Scheduled','Skin rash'),
(3,3,'2025-11-22','09:30:00','Scheduled','Fever');

-- medicines
INSERT INTO medicines(medicine_name, brand, batch_no, unit_price, quantity, expiry_date)
VALUES
('Paracetamol','Paracare','B001',5.00,100,'2026-08-01'),
('Amoxicillin','Amoxi','B002',12.50,50,'2025-12-01'),
('Cetirizine','Zyrin','B003',3.50,200,'2027-01-10');

-- pharmacy_orders & items
INSERT INTO pharmacy_orders(patient_id, order_date, total_amount, payment_status)
VALUES (1, now(), 25.00, 'Paid');
INSERT INTO pharmacy_order_items(order_id, medicine_id, quantity, price_each)
VALUES (currval('pharmacy_orders_order_id_seq'), 1, 5, 5.00); -- 5*5=25

-- billing example (for appointment)
INSERT INTO billing(patient_id, appointment_id, amount, bill_date, paid, payment_method)
VALUES (1, 1, 750.00, now(), TRUE, 'Card');


--4 — Useful Views (for reporting)

-- View: upcoming appointments (next 30 days)
CREATE OR REPLACE VIEW v_upcoming_appointments AS
SELECT a.appointment_id, p.full_name AS patient, d.full_name AS doctor, a.appointment_date, a.appointment_time, a.status
FROM appointments a
JOIN patients p ON a.patient_id = p.patient_id
LEFT JOIN doctors d ON a.doctor_id = d.doctor_id
WHERE a.appointment_date >= current_date
ORDER BY a.appointment_date, a.appointment_time;

-- View: current medicine stock
CREATE OR REPLACE VIEW v_medicine_stock AS
SELECT medicine_id, medicine_name, brand, quantity, expiry_date
FROM medicines
ORDER BY medicine_name;     



--5 — Functions & Procedures (PL/pgSQL)

--Postgres uses functions — here are practical ones.

-- Function: Book appointment (returns appointment_id)
CREATE OR REPLACE FUNCTION fn_book_appointment(p_patient INT, p_doctor INT, p_date DATE, p_time TIME, p_reason TEXT)
RETURNS INT LANGUAGE plpgsql AS $$
DECLARE
  a_id INT;
BEGIN
  INSERT INTO appointments(patient_id, doctor_id, appointment_date, appointment_time, status, reason)
  VALUES (p_patient, p_doctor, p_date, p_time, 'Scheduled', p_reason)
  RETURNING appointment_id INTO a_id;
  RETURN a_id;
END;
$$;

-- Function: Create pharmacy order (reduces stock, creates order and items, returns order_id)
CREATE OR REPLACE FUNCTION fn_create_pharmacy_order(p_patient INT, p_items JSON)
RETURNS INT LANGUAGE plpgsql AS $$
-- p_items example: '[{"medicine_id":1,"qty":2},{"medicine_id":3,"qty":1}]'
DECLARE
  oid INT;
  it JSON;
  mid INT;
  qty INT;
  price NUMERIC;
  total NUMERIC := 0;
BEGIN
  -- Create order
  INSERT INTO pharmacy_orders(patient_id, total_amount, payment_status) VALUES (p_patient, 0, 'Pending') RETURNING order_id INTO oid;

  FOR it IN SELECT * FROM json_array_elements(p_items)
  LOOP
    mid := (it->>'medicine_id')::INT;
    qty := (it->>'qty')::INT;
    SELECT unit_price INTO price FROM medicines WHERE medicine_id = mid;
    IF price IS NULL THEN
      RAISE EXCEPTION 'Medicine % not found', mid;
    END IF;
    -- check stock
    UPDATE medicines SET quantity = quantity - qty WHERE medicine_id = mid AND quantity >= qty;
    IF NOT FOUND THEN
      RAISE EXCEPTION 'Insufficient stock for medicine %', mid;
    END IF;
    INSERT INTO pharmacy_order_items(order_id, medicine_id, quantity, price_each) VALUES (oid, mid, qty, price);
    total := total + price * qty;
  END LOOP;

  UPDATE pharmacy_orders SET total_amount = total WHERE order_id = oid;
  RETURN oid;
END;
$$;

--Example call (run as SQL):

SELECT fn_book_appointment(1,1,'2025-11-28','09:00:00','Follow up');

-- Create an order with JSON array
SELECT fn_create_pharmacy_order(1, '[{"medicine_id":1,"qty":2},{"medicine_id":3,"qty":1}]'::json);


---6 Triggers for data integrity & alerts

-- Trigger: Prevent inserting expired medicine
CREATE OR REPLACE FUNCTION trg_no_expired_medicine()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF NEW.expiry_date IS NOT NULL AND NEW.expiry_date < current_date THEN
    RAISE EXCEPTION 'Cannot insert expired medicine (expiry=%)', NEW.expiry_date;
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_prevent_expired BEFORE INSERT OR UPDATE ON medicines
FOR EACH ROW EXECUTE FUNCTION trg_no_expired_medicine();

-- Trigger: Log appointment status change (simple audit table)
DROP TABLE IF EXISTS appointment_audit;
CREATE TABLE appointment_audit (
  audit_id SERIAL PRIMARY KEY,
  appointment_id INT,
  old_status TEXT,
  new_status TEXT,
  changed_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

CREATE OR REPLACE FUNCTION trg_appointment_status_audit()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF TG_OP = 'UPDATE' AND OLD.status IS DISTINCT FROM NEW.status THEN
    INSERT INTO appointment_audit(appointment_id, old_status, new_status) VALUES (OLD.appointment_id, OLD.status, NEW.status);
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_app_status AFTER UPDATE ON appointments FOR EACH ROW EXECUTE FUNCTION trg_appointment_status_audit();

--1. List all patients (id, name, phone, email).

SELECT patient_id, full_name, phone, email FROM patients ORDER BY full_name;


--2. Show upcoming appointments (next 7 days).

SELECT * FROM v_upcoming_appointments WHERE appointment_date <= current_date + interval '7 days';

--3. Find all appointments for a given doctor (doctor_id = 2).

SELECT a.*, p.full_name AS patient
FROM appointments a JOIN patients p ON a.patient_id = p.patient_id
WHERE a.doctor_id = 2 ORDER BY appointment_date, appointment_time;

--4. Get medicine stock that is low (quantity < 20).

SELECT medicine_id, medicine_name, quantity FROM medicines WHERE quantity < 20;

--5. Show medicines expiring within 90 days.

SELECT medicine_id, medicine_name, expiry_date FROM medicines
WHERE expiry_date BETWEEN current_date AND current_date + interval '90 days'
ORDER BY expiry_date;

--6. Generate a billing summary for a patient (patient_id = 1).

SELECT b.bill_id, b.amount, b.paid, b.payment_method, b.bill_date, a.appointment_id, po.order_id
FROM billing b
LEFT JOIN appointments a ON b.appointment_id = a.appointment_id
LEFT JOIN pharmacy_orders po ON b.order_id = po.order_id
WHERE b.patient_id = 1;

--7. Total revenue by day (last 30 days).

SELECT date_trunc('day',bill_date) AS day, SUM(amount) AS total_revenue
FROM billing
WHERE bill_date >= now() - interval '30 days'
GROUP BY day ORDER BY day;

--8. Find top 5 most sold medicines (by quantity) — across orders.

SELECT m.medicine_id, m.medicine_name, SUM(i.quantity) AS total_sold
FROM pharmacy_order_items i
JOIN medicines m ON i.medicine_id = m.medicine_id
GROUP BY m.medicine_id, m.medicine_name
ORDER BY total_sold DESC LIMIT 5;

--9. List patients who never visited (no appointments).

SELECT p.* FROM patients p
LEFT JOIN appointments a ON p.patient_id = a.patient_id
WHERE a.appointment_id IS NULL;

--10. Mark an appointment as completed and add billing entry.

BEGIN;
UPDATE appointments SET status='Completed' WHERE appointment_id=1;
INSERT INTO billing(patient_id, appointment_id, amount, paid, payment_method) VALUES (1,1,800.00,TRUE,'Card');
COMMIT;



