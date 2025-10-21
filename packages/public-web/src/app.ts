/**
 * Public Web Service - Express Application
 */

import express from 'express';
import { router } from './api/routes';
import { errorMiddleware } from './api/middleware/error.middleware';
import { logger } from '@sample-app/shared';

export const app = express();

// Middleware
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// Request logging
app.use((req, res, next) => {
  logger.info(`${req.method} ${req.path}`, {
    method: req.method,
    path: req.path,
    query: req.query,
  });
  next();
});

// Health check endpoint
app.get('/health', (req, res) => {
  res.status(200).json({
    status: 'ok',
    timestamp: new Date().toISOString(),
  });
});

// API routes
app.use('/api/v1', router);

// Error handling
app.use(errorMiddleware);
