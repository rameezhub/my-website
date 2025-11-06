const mysql = require('mysql2');

const db = mysql.createConnection({
  host: 'localhost',
  user: 'root',
  password: 'yourpassword',
  database: 'vehicle_rental_db',
  multipleStatements: true
});

db.connect(err => {
  if (err) {
    console.error('MySQL connection error:', err.message);
    throw err;
  }
  console.log('✅ MySQL connected');
});

module.exports = db;
