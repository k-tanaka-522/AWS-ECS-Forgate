const { Pool } = require('pg');
const logger = require('./logger');

/**
 * PostgreSQL Connection Pool Manager
 * Provides a singleton connection pool for database access
 */
class DatabasePool {
  constructor() {
    this.pool = null;
  }

  /**
   * Initialize database connection pool
   * @returns {Pool} PostgreSQL connection pool
   */
  initialize() {
    if (this.pool) {
      logger.info('Database pool already initialized');
      return this.pool;
    }

    const config = {
      host: process.env.DB_HOST,
      port: parseInt(process.env.DB_PORT || '5432', 10),
      database: process.env.DB_NAME,
      user: process.env.DB_USER || 'postgres',
      password: process.env.DB_PASSWORD,
      max: 20, // Maximum pool size
      idleTimeoutMillis: 30000,
      connectionTimeoutMillis: 5000,
    };

    // Validate required environment variables
    if (!config.host || !config.database || !config.password) {
      const error = new Error(
        'Missing required database configuration: DB_HOST, DB_NAME, DB_PASSWORD'
      );
      logger.error('Database configuration error', { error: error.message });
      throw error;
    }

    this.pool = new Pool(config);

    // Connection event handlers
    this.pool.on('connect', (client) => {
      logger.debug('New database client connected', {
        totalCount: this.pool.totalCount,
        idleCount: this.pool.idleCount,
        waitingCount: this.pool.waitingCount,
      });
    });

    this.pool.on('acquire', (client) => {
      logger.debug('Client acquired from pool', {
        totalCount: this.pool.totalCount,
        idleCount: this.pool.idleCount,
        waitingCount: this.pool.waitingCount,
      });
    });

    this.pool.on('error', (err, client) => {
      logger.error('Unexpected database pool error', {
        error: err.message,
        stack: err.stack,
      });
    });

    this.pool.on('remove', (client) => {
      logger.debug('Client removed from pool', {
        totalCount: this.pool.totalCount,
        idleCount: this.pool.idleCount,
        waitingCount: this.pool.waitingCount,
      });
    });

    logger.info('Database connection pool initialized', {
      host: config.host,
      port: config.port,
      database: config.database,
      maxConnections: config.max,
    });

    return this.pool;
  }

  /**
   * Get the connection pool instance
   * @returns {Pool} PostgreSQL connection pool
   */
  getPool() {
    if (!this.pool) {
      throw new Error('Database pool not initialized. Call initialize() first.');
    }
    return this.pool;
  }

  /**
   * Execute a query
   * @param {string} text - SQL query text
   * @param {Array} params - Query parameters
   * @returns {Promise<Object>} Query result
   */
  async query(text, params = []) {
    const start = Date.now();
    try {
      const result = await this.pool.query(text, params);
      const duration = Date.now() - start;

      logger.debug('Database query executed', {
        query: text,
        duration: `${duration}ms`,
        rows: result.rowCount,
      });

      return result;
    } catch (error) {
      logger.error('Database query error', {
        query: text,
        error: error.message,
        stack: error.stack,
      });
      throw error;
    }
  }

  /**
   * Test database connection
   * @returns {Promise<boolean>} True if connection is successful
   */
  async testConnection() {
    try {
      const result = await this.query('SELECT NOW() as current_time, version()');
      logger.info('Database connection test successful', {
        timestamp: result.rows[0].current_time,
        version: result.rows[0].version,
      });
      return true;
    } catch (error) {
      logger.error('Database connection test failed', {
        error: error.message,
      });
      return false;
    }
  }

  /**
   * Get connection pool statistics
   * @returns {Object} Pool statistics
   */
  getStats() {
    if (!this.pool) {
      return null;
    }

    return {
      totalCount: this.pool.totalCount,
      idleCount: this.pool.idleCount,
      waitingCount: this.pool.waitingCount,
    };
  }

  /**
   * Close all connections in the pool
   * @returns {Promise<void>}
   */
  async close() {
    if (this.pool) {
      logger.info('Closing database connection pool');
      await this.pool.end();
      this.pool = null;
      logger.info('Database connection pool closed');
    }
  }
}

// Singleton instance
const dbPool = new DatabasePool();

module.exports = dbPool;
