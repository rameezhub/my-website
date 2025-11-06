const express = require('express');
const bodyParser = require('body-parser');
const cors = require('cors');
const db = require('./db');

const app = express();
app.use(cors());
app.use(bodyParser.json());
app.use(express.static('public'));

// ➕ Add Customer
app.post('/customer', (req, res) => {
  const { first_name, last_name, address, city, state, phone, email, license } = req.body;
  const sql = `INSERT INTO Customer (first_name, last_name, address, city, state, phone, email, license)
               VALUES (?, ?, ?, ?, ?, ?, ?, ?)`;
  db.query(sql, [first_name, last_name, address, city, state, phone, email, license], (err, result) => {
    if (err) return res.status(500).send(err.message);
    res.send('✅ Customer added successfully');
  });
});

// 🚗 Get Available Vehicles
app.get('/vehicles', (req, res) => {
  db.query('SELECT * FROM Vehicle WHERE status="Available"', (err, rows) => {
    if (err) return res.status(500).send(err.message);
    res.json(rows);
  });
});

// 📅 Create Reservation
app.post('/reservation', (req, res) => {
  const { customer_id, vehicle_id, start_date, end_date } = req.body;
  const sql = `CALL CreateReservation(?, ?, ?, ?)`;
  db.query(sql, [customer_id, vehicle_id, start_date, end_date], (err, result) => {
    if (err) return res.status(500).send(err.message);
    res.send('✅ Reservation created successfully');
  });
});

// 🧾 Generate Rental
app.post('/rental', (req, res) => {
  const { reservation_id, staff_id } = req.body;
  const sql = `CALL GenerateRental(?, ?)`;
  db.query(sql, [reservation_id, staff_id], (err, result) => {
    if (err) return res.status(500).send(err.message);
    res.send('✅ Rental generated successfully');
  });
});

// 💳 Record Payment
app.post('/payment', (req, res) => {
  const { rental_id, amount, mode_of_payment } = req.body;
  const sql = `INSERT INTO Payment (rental_id, payment_date, amount, mode_of_payment)
               VALUES (?, CURDATE(), ?, ?)`;
  db.query(sql, [rental_id, amount, mode_of_payment], (err, result) => {
    if (err) return res.status(500).send(err.message);
    res.send('✅ Payment recorded successfully');
  });
});

// 📊 View Rental Summary
app.get('/summary', (req, res) => {
  db.query('SELECT * FROM RentalSummary', (err, rows) => {
    if (err) return res.status(500).send(err.message);
    res.json(rows);
  });
});

app.listen(3000, () => console.log('🚀 Server running on http://localhost:3000'));
