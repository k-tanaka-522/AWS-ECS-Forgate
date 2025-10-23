const createApp = require('./app');
const { logger, db } = require('@sample-app/shared');

const PORT = process.env.PORT || 3000;

/**
 * Start the Public Web Service
 */
async function start() {
  try {
    // Initialize database connection pool
    db.initialize();

    // Test database connection
    const isConnected = await db.testConnection();
    if (!isConnected) {
      throw new Error('Failed to connect to database');
    }

    // Create Express app
    const app = createApp();

    // Start server
    const server = app.listen(PORT, '0.0.0.0', () => {
      logger.info('Public Web Service started', {
        port: PORT,
        nodeEnv: process.env.NODE_ENV || 'development',
        pid: process.pid,
      });
    });

    // Graceful shutdown
    const gracefulShutdown = async (signal) => {
      logger.info('Graceful shutdown initiated', { signal });

      server.close(async () => {
        logger.info('HTTP server closed');

        try {
          await db.close();
          logger.info('Database connection closed');
          process.exit(0);
        } catch (error) {
          logger.error('Error during shutdown', { error: error.message });
          process.exit(1);
        }
      });

      // Force shutdown after 30 seconds
      setTimeout(() => {
        logger.error('Forced shutdown after timeout');
        process.exit(1);
      }, 30000);
    };

    process.on('SIGTERM', () => gracefulShutdown('SIGTERM'));
    process.on('SIGINT', () => gracefulShutdown('SIGINT'));
  } catch (error) {
    logger.error('Failed to start Public Web Service', {
      error: error.message,
      stack: error.stack,
    });
    process.exit(1);
  }
}

// Start the service
start();
