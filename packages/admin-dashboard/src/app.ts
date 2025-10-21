/**
 * Admin Dashboard Service - Express Application
 */

import express from 'express';
import { router } from './api/routes';
import { logger } from '@sample-app/shared';

export const app = express();

app.use(express.json());

app.get('/health', (req, res) => {
  res.status(200).json({ status: 'ok', timestamp: new Date().toISOString() });
});

app.use('/api/v1/admin', router);

app.use((err: Error, req: express.Request, res: express.Response, next: express.NextFunction) => {
  logger.error('Request error', err);
  res.status(500).json({ error: { code: 'INTERNAL_ERROR', message: err.message } });
});
