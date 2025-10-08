const express = require('express');
const { Pool } = require('pg');

const app = express();
const port = process.env.PORT || 3000;

// PostgreSQL connection pool
const pool = new Pool({
  host: process.env.DB_HOST,
  port: process.env.DB_PORT || 5432,
  database: process.env.DB_NAME || 'careapp',
  user: process.env.DB_USER || 'postgres',
  password: process.env.DB_PASSWORD,
  max: 20,
  idleTimeoutMillis: 30000,
  connectionTimeoutMillis: 2000,
});

// Test database connection on startup
pool.query('SELECT NOW()', (err, res) => {
  if (err) {
    console.error('Database connection failed:', err);
  } else {
    console.log('Database connected successfully at:', res.rows[0].now);
  }
});

// Health check endpoint (for ALB)
app.get('/health', (req, res) => {
  res.status(200).json({ status: 'healthy' });
});

// Main endpoint - fetch message from database
app.get('/', async (req, res) => {
  try {
    const result = await pool.query('SELECT message FROM messages WHERE id = 1');

    if (result.rows.length > 0) {
      const message = result.rows[0].message;
      res.send(`
        <!DOCTYPE html>
        <html lang="ja">
        <head>
          <meta charset="UTF-8">
          <meta name="viewport" content="width=device-width, initial-scale=1.0">
          <title>Hello ECS Service</title>
          <style>
            body {
              font-family: Arial, sans-serif;
              display: flex;
              justify-content: center;
              align-items: center;
              min-height: 100vh;
              margin: 0;
              background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            }
            .container {
              text-align: center;
              background: white;
              padding: 3rem;
              border-radius: 10px;
              box-shadow: 0 10px 30px rgba(0,0,0,0.2);
            }
            h1 {
              color: #667eea;
              margin-bottom: 1rem;
            }
            p {
              color: #555;
              font-size: 1.2rem;
            }
            .info {
              margin-top: 2rem;
              padding: 1rem;
              background: #f5f5f5;
              border-radius: 5px;
              font-size: 0.9rem;
              color: #666;
            }
          </style>
        </head>
        <body>
          <div class="container">
            <h1>${message}</h1>
            <p>🚀 Running on AWS ECS Fargate</p>
            <p>📦 PostgreSQL RDS Database</p>
            <div class="info">
              <strong>Environment:</strong> ${process.env.NODE_ENV || 'development'}<br>
              <strong>DB Host:</strong> ${process.env.DB_HOST}<br>
              <strong>Container:</strong> ECS Fargate Task
            </div>
          </div>
        </body>
        </html>
      `);
    } else {
      res.status(404).send('Message not found in database');
    }
  } catch (error) {
    console.error('Database query error:', error);
    res.status(500).send(`
      <h1>Database Error</h1>
      <p>Could not fetch message from database.</p>
      <pre>${error.message}</pre>
    `);
  }
});

// API endpoint to fetch all messages
app.get('/api/messages', async (req, res) => {
  try {
    const result = await pool.query('SELECT * FROM messages ORDER BY id');
    res.json(result.rows);
  } catch (error) {
    console.error('Database query error:', error);
    res.status(500).json({ error: error.message });
  }
});

// Graceful shutdown
process.on('SIGTERM', () => {
  console.log('SIGTERM received, closing server...');
  pool.end(() => {
    console.log('Database pool closed');
    process.exit(0);
  });
});

app.listen(port, () => {
  console.log(`Server running on port ${port}`);
  console.log(`Environment: ${process.env.NODE_ENV}`);
  console.log(`Database: ${process.env.DB_HOST}:${process.env.DB_PORT}/${process.env.DB_NAME}`);
});
