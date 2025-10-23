const express = require('express');
const helmet = require('helmet');
const cors = require('cors');
const compression = require('compression');
const { logger, db } = require('@sample-app/shared');

/**
 * Create and configure Express application
 * @returns {express.Application}
 */
function createApp() {
  const app = express();

  // Security middleware
  app.use(helmet());

  // CORS configuration
  app.use(
    cors({
      origin: process.env.CORS_ORIGIN || '*',
      methods: ['GET', 'POST', 'PUT', 'DELETE'],
      allowedHeaders: ['Content-Type', 'Authorization'],
    })
  );

  // Compression middleware
  app.use(compression());

  // Body parser
  app.use(express.json({ limit: '10mb' }));
  app.use(express.urlencoded({ extended: true, limit: '10mb' }));

  // Request logging middleware
  app.use((req, res, next) => {
    const start = Date.now();
    res.on('finish', () => {
      const duration = Date.now() - start;
      logger.info('HTTP Request', {
        method: req.method,
        path: req.path,
        statusCode: res.statusCode,
        duration: `${duration}ms`,
        ip: req.ip,
        userAgent: req.get('user-agent'),
      });
    });
    next();
  });

  // Health check endpoint
  app.get('/health', async (req, res) => {
    try {
      const dbConnected = await db.testConnection();
      const poolStats = db.getStats();

      const health = {
        status: dbConnected ? 'healthy' : 'unhealthy',
        timestamp: new Date().toISOString(),
        service: 'public-web',
        database: {
          connected: dbConnected,
          pool: poolStats,
        },
        uptime: process.uptime(),
        memory: process.memoryUsage(),
      };

      const statusCode = dbConnected ? 200 : 503;
      res.status(statusCode).json(health);
    } catch (error) {
      logger.error('Health check failed', { error: error.message });
      res.status(503).json({
        status: 'unhealthy',
        error: error.message,
      });
    }
  });

  // API Routes
  // GET /api/users - List all users
  app.get('/api/users', async (req, res) => {
    try {
      const result = await db.query(
        'SELECT id, username, email, created_at, updated_at FROM users ORDER BY created_at DESC LIMIT 100'
      );

      res.json({
        success: true,
        data: result.rows,
        count: result.rowCount,
      });
    } catch (error) {
      logger.error('Failed to fetch users', { error: error.message });
      res.status(500).json({
        success: false,
        error: 'Failed to fetch users',
      });
    }
  });

  // POST /api/users - Create new user
  app.post('/api/users', async (req, res) => {
    try {
      const { username, email } = req.body;

      // Validation
      if (!username || !email) {
        return res.status(400).json({
          success: false,
          error: 'Username and email are required',
        });
      }

      // Email format validation
      const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
      if (!emailRegex.test(email)) {
        return res.status(400).json({
          success: false,
          error: 'Invalid email format',
        });
      }

      const result = await db.query(
        'INSERT INTO users (username, email) VALUES ($1, $2) RETURNING id, username, email, created_at',
        [username, email]
      );

      logger.info('User created', {
        userId: result.rows[0].id,
        username,
      });

      res.status(201).json({
        success: true,
        data: result.rows[0],
      });
    } catch (error) {
      // Handle unique constraint violation
      if (error.code === '23505') {
        return res.status(409).json({
          success: false,
          error: 'Username or email already exists',
        });
      }

      logger.error('Failed to create user', { error: error.message });
      res.status(500).json({
        success: false,
        error: 'Failed to create user',
      });
    }
  });

  // GET /api/users/:id - Get user by ID
  app.get('/api/users/:id', async (req, res) => {
    try {
      const { id } = req.params;

      const result = await db.query(
        'SELECT id, username, email, created_at, updated_at FROM users WHERE id = $1',
        [id]
      );

      if (result.rowCount === 0) {
        return res.status(404).json({
          success: false,
          error: 'User not found',
        });
      }

      res.json({
        success: true,
        data: result.rows[0],
      });
    } catch (error) {
      logger.error('Failed to fetch user', {
        userId: req.params.id,
        error: error.message,
      });
      res.status(500).json({
        success: false,
        error: 'Failed to fetch user',
      });
    }
  });

  // GET /api/stats - Get statistics
  app.get('/api/stats', async (req, res) => {
    try {
      const result = await db.query(
        'SELECT metric_name, metric_value, recorded_at FROM stats ORDER BY recorded_at DESC LIMIT 100'
      );

      res.json({
        success: true,
        data: result.rows,
        count: result.rowCount,
      });
    } catch (error) {
      logger.error('Failed to fetch stats', { error: error.message });
      res.status(500).json({
        success: false,
        error: 'Failed to fetch stats',
      });
    }
  });

  // POST /api/stats - Record new statistic
  app.post('/api/stats', async (req, res) => {
    try {
      const { metric_name, metric_value } = req.body;

      if (!metric_name || metric_value === undefined) {
        return res.status(400).json({
          success: false,
          error: 'metric_name and metric_value are required',
        });
      }

      const result = await db.query(
        'INSERT INTO stats (metric_name, metric_value) VALUES ($1, $2) RETURNING id, metric_name, metric_value, recorded_at',
        [metric_name, metric_value]
      );

      res.status(201).json({
        success: true,
        data: result.rows[0],
      });
    } catch (error) {
      logger.error('Failed to record stat', { error: error.message });
      res.status(500).json({
        success: false,
        error: 'Failed to record stat',
      });
    }
  });

  // 404 handler
  app.use((req, res) => {
    res.status(404).json({
      success: false,
      error: 'Not found',
    });
  });

  // Error handler
  app.use((err, req, res, next) => {
    logger.error('Unhandled error', {
      error: err.message,
      stack: err.stack,
      path: req.path,
      method: req.method,
    });

    res.status(500).json({
      success: false,
      error: 'Internal server error',
    });
  });

  return app;
}

module.exports = createApp;
