/**
 * Public Web Service - Entry Point
 */

import { app } from './app';
import { logger } from '@sample-app/shared';

const PORT = parseInt(process.env.PORT || '3000', 10);

app.listen(PORT, () => {
  logger.info(`Public Web Service listening on port ${PORT}`, {
    environment: process.env.NODE_ENV,
    port: PORT,
  });
});

// Graceful shutdown
process.on('SIGTERM', () => {
  logger.info('SIGTERM received, shutting down gracefully');
  process.exit(0);
});

process.on('SIGINT', () => {
  logger.info('SIGINT received, shutting down gracefully');
  process.exit(0);
});
