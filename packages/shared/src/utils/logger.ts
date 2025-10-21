/**
 * Logger Utility
 *
 * JSON-formatted logging for CloudWatch Logs
 */

type LogLevel = 'DEBUG' | 'INFO' | 'WARN' | 'ERROR';

interface LogEntry {
  timestamp: string;
  level: LogLevel;
  service: string;
  message: string;
  context?: any;
}

const SERVICE_NAME = process.env.SERVICE_NAME || 'unknown-service';
const LOG_LEVEL = (process.env.LOG_LEVEL || 'info').toUpperCase() as LogLevel;

const LOG_LEVELS: Record<LogLevel, number> = {
  DEBUG: 0,
  INFO: 1,
  WARN: 2,
  ERROR: 3,
};

function shouldLog(level: LogLevel): boolean {
  return LOG_LEVELS[level] >= LOG_LEVELS[LOG_LEVEL];
}

function log(level: LogLevel, message: string, context?: any): void {
  if (!shouldLog(level)) {
    return;
  }

  const entry: LogEntry = {
    timestamp: new Date().toISOString(),
    level,
    service: SERVICE_NAME,
    message,
  };

  if (context) {
    entry.context = context;
  }

  console.log(JSON.stringify(entry));
}

export const logger = {
  debug(message: string, context?: any): void {
    log('DEBUG', message, context);
  },

  info(message: string, context?: any): void {
    log('INFO', message, context);
  },

  warn(message: string, context?: any): void {
    log('WARN', message, context);
  },

  error(message: string, error?: Error | any): void {
    const context = error instanceof Error
      ? {
          message: error.message,
          stack: error.stack,
          ...error,
        }
      : error;

    log('ERROR', message, context);
  },
};
