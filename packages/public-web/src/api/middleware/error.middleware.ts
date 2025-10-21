/**
 * Error Handling Middleware
 */

import { Request, Response, NextFunction } from 'express';
import { ValidationError, logger } from '@sample-app/shared';

export function errorMiddleware(err: Error, req: Request, res: Response, next: NextFunction): void {
  logger.error('Request error', err);

  if (err instanceof ValidationError) {
    return res.status(400).json({
      error: {
        code: 'VALIDATION_ERROR',
        message: err.message,
        details: [
          {
            field: err.field,
            reason: err.message,
          },
        ],
      },
    });
  }

  // Default error response
  res.status(500).json({
    error: {
      code: 'INTERNAL_ERROR',
      message: 'An internal server error occurred',
    },
  });
}
