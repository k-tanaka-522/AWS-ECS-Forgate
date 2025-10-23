const winston = require('winston');

/**
 * Create Winston logger with CloudWatch-compatible format
 * Logs are structured as JSON for CloudWatch Logs Insights
 */
const createLogger = () => {
  const logLevel = process.env.LOG_LEVEL || 'info';
  const nodeEnv = process.env.NODE_ENV || 'development';

  // Custom format for CloudWatch
  const cloudWatchFormat = winston.format.combine(
    winston.format.timestamp({ format: 'YYYY-MM-DD HH:mm:ss.SSS' }),
    winston.format.errors({ stack: true }),
    winston.format.metadata({ fillExcept: ['message', 'level', 'timestamp'] }),
    winston.format.json()
  );

  // Human-readable format for local development
  const developmentFormat = winston.format.combine(
    winston.format.colorize(),
    winston.format.timestamp({ format: 'YYYY-MM-DD HH:mm:ss' }),
    winston.format.errors({ stack: true }),
    winston.format.printf(({ level, message, timestamp, ...metadata }) => {
      let msg = `${timestamp} [${level}]: ${message}`;
      if (Object.keys(metadata).length > 0) {
        msg += ` ${JSON.stringify(metadata)}`;
      }
      return msg;
    })
  );

  const logger = winston.createLogger({
    level: logLevel,
    format: nodeEnv === 'production' ? cloudWatchFormat : developmentFormat,
    defaultMeta: {
      service: process.env.SERVICE_NAME || 'sample-app',
      environment: nodeEnv,
    },
    transports: [
      new winston.transports.Console({
        stderrLevels: ['error'],
      }),
    ],
  });

  // Log unhandled promise rejections
  process.on('unhandledRejection', (reason, promise) => {
    logger.error('Unhandled Promise Rejection', {
      reason: reason instanceof Error ? reason.message : reason,
      stack: reason instanceof Error ? reason.stack : undefined,
      promise: String(promise),
    });
  });

  // Log uncaught exceptions
  process.on('uncaughtException', (error) => {
    logger.error('Uncaught Exception', {
      error: error.message,
      stack: error.stack,
    });
    // Give logger time to write before exiting
    setTimeout(() => {
      process.exit(1);
    }, 1000);
  });

  return logger;
};

// Singleton logger instance
const logger = createLogger();

module.exports = logger;
