/**
 * Admin Dashboard Service - Entry Point
 */

import { app } from './app';
import { logger } from '@sample-app/shared';

const PORT = parseInt(process.env.PORT || '3001', 10);

app.listen(PORT, () => {
  logger.info(`Admin Dashboard Service listening on port ${PORT}`, {
    environment: process.env.NODE_ENV,
    port: PORT,
  });
});

process.on('SIGTERM', () => {
  logger.info('SIGTERM received, shutting down gracefully');
  process.exit(0);
});
