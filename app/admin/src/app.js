const express = require('express');
const helmet = require('helmet');
const compression = require('compression');
const { logger, db } = require('@sample-app/shared');

/**
 * Create and configure Admin Dashboard Express application
 * @returns {express.Application}
 */
function createApp() {
  const app = express();

  // Security middleware
  app.use(helmet());

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
      logger.info('Admin HTTP Request', {
        method: req.method,
        path: req.path,
        statusCode: res.statusCode,
        duration: `${duration}ms`,
        ip: req.ip,
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
        service: 'admin',
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

  // Dashboard home
  app.get('/', (req, res) => {
    res.json({
      service: 'Admin Dashboard',
      version: '1.0.0',
      endpoints: [
        'GET /health - Health check',
        'GET /admin/users - List all users with details',
        'DELETE /admin/users/:id - Delete user',
        'GET /admin/stats - System statistics',
        'POST /admin/stats/clear - Clear old statistics',
        'GET /admin/database/info - Database information',
      ],
    });
  });

  // Admin API Routes
  // GET /admin/users - List all users (admin view with more details)
  app.get('/admin/users', async (req, res) => {
    try {
      const result = await db.query(`
        SELECT
          id,
          username,
          email,
          created_at,
          updated_at,
          (SELECT COUNT(*) FROM stats WHERE metric_name = 'user_action_' || users.id::text) as action_count
        FROM users
        ORDER BY created_at DESC
      `);

      res.json({
        success: true,
        data: result.rows,
        count: result.rowCount,
        timestamp: new Date().toISOString(),
      });
    } catch (error) {
      logger.error('Admin: Failed to fetch users', { error: error.message });
      res.status(500).json({
        success: false,
        error: 'Failed to fetch users',
      });
    }
  });

  // DELETE /admin/users/:id - Delete user (admin only)
  app.delete('/admin/users/:id', async (req, res) => {
    try {
      const { id } = req.params;

      const result = await db.query('DELETE FROM users WHERE id = $1 RETURNING id, username', [
        id,
      ]);

      if (result.rowCount === 0) {
        return res.status(404).json({
          success: false,
          error: 'User not found',
        });
      }

      logger.info('Admin: User deleted', {
        userId: result.rows[0].id,
        username: result.rows[0].username,
      });

      res.json({
        success: true,
        message: 'User deleted successfully',
        data: result.rows[0],
      });
    } catch (error) {
      logger.error('Admin: Failed to delete user', {
        userId: req.params.id,
        error: error.message,
      });
      res.status(500).json({
        success: false,
        error: 'Failed to delete user',
      });
    }
  });

  // GET /admin/stats - System statistics
  app.get('/admin/stats', async (req, res) => {
    try {
      const [userCount, statsCount, recentStats] = await Promise.all([
        db.query('SELECT COUNT(*) as count FROM users'),
        db.query('SELECT COUNT(*) as count FROM stats'),
        db.query(
          'SELECT metric_name, COUNT(*) as count, AVG(metric_value) as avg_value, MIN(recorded_at) as first_recorded, MAX(recorded_at) as last_recorded FROM stats GROUP BY metric_name ORDER BY count DESC LIMIT 10'
        ),
      ]);

      res.json({
        success: true,
        data: {
          users: {
            total: parseInt(userCount.rows[0].count, 10),
          },
          stats: {
            total: parseInt(statsCount.rows[0].count, 10),
            byMetric: recentStats.rows,
          },
          database: db.getStats(),
        },
        timestamp: new Date().toISOString(),
      });
    } catch (error) {
      logger.error('Admin: Failed to fetch system stats', { error: error.message });
      res.status(500).json({
        success: false,
        error: 'Failed to fetch system statistics',
      });
    }
  });

  // POST /admin/stats/clear - Clear old statistics (older than 90 days)
  app.post('/admin/stats/clear', async (req, res) => {
    try {
      const daysToKeep = req.body.days || 90;

      const result = await db.query(
        "DELETE FROM stats WHERE recorded_at < NOW() - INTERVAL '$1 days' RETURNING metric_name",
        [daysToKeep]
      );

      logger.info('Admin: Old stats cleared', {
        deletedCount: result.rowCount,
        daysToKeep,
      });

      res.json({
        success: true,
        message: `Cleared statistics older than ${daysToKeep} days`,
        deletedCount: result.rowCount,
      });
    } catch (error) {
      logger.error('Admin: Failed to clear stats', { error: error.message });
      res.status(500).json({
        success: false,
        error: 'Failed to clear statistics',
      });
    }
  });

  // GET /admin/database/info - Database connection and version info
  app.get('/admin/database/info', async (req, res) => {
    try {
      const [version, settings, activity] = await Promise.all([
        db.query('SELECT version()'),
        db.query(
          "SELECT name, setting, unit FROM pg_settings WHERE name IN ('max_connections', 'shared_buffers', 'effective_cache_size', 'work_mem')"
        ),
        db.query(
          'SELECT COUNT(*) as active_connections, COUNT(*) FILTER (WHERE state = \'active\') as active_queries FROM pg_stat_activity WHERE datname = current_database()'
        ),
      ]);

      res.json({
        success: true,
        data: {
          version: version.rows[0].version,
          settings: settings.rows,
          activity: activity.rows[0],
          pool: db.getStats(),
        },
        timestamp: new Date().toISOString(),
      });
    } catch (error) {
      logger.error('Admin: Failed to fetch database info', { error: error.message });
      res.status(500).json({
        success: false,
        error: 'Failed to fetch database information',
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
    logger.error('Admin: Unhandled error', {
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
