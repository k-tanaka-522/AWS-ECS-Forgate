/**
 * Authentication Middleware
 */

import { Request, Response, NextFunction } from 'express';
import jwt from 'jsonwebtoken';
import { logger } from '@sample-app/shared';

interface JWTPayload {
  userId: string;
  email: string;
}

export async function authMiddleware(req: Request, res: Response, next: NextFunction): Promise<void> {
  try {
    const authHeader = req.headers.authorization;

    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return res.status(401).json({
        error: {
          code: 'UNAUTHORIZED',
          message: 'Authentication required',
        },
      });
    }

    const token = authHeader.substring(7);
    const jwtSecret = process.env.JWT_SECRET || 'development-secret-change-in-production';

    const decoded = jwt.verify(token, jwtSecret) as JWTPayload;

    (req as any).user = {
      userId: decoded.userId,
      email: decoded.email,
    };

    next();
  } catch (error) {
    logger.error('Authentication failed', error);

    return res.status(401).json({
      error: {
        code: 'UNAUTHORIZED',
        message: 'Invalid or expired token',
      },
    });
  }
}
