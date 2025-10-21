import { Request, Response, NextFunction } from 'express';

export async function authMiddleware(req: Request, res: Response, next: NextFunction): Promise<void> {
  const authHeader = req.headers.authorization;

  if (!authHeader || !authHeader.startsWith('Basic ')) {
    return res.status(401).json({ error: { code: 'UNAUTHORIZED', message: 'Authentication required' } });
  }

  const credentials = Buffer.from(authHeader.substring(6), 'base64').toString();
  const [username, password] = credentials.split(':');

  const adminUsername = process.env.ADMIN_USERNAME || 'admin';
  const adminPassword = process.env.ADMIN_PASSWORD || 'admin';

  if (username === adminUsername && password === adminPassword) {
    next();
  } else {
    return res.status(401).json({ error: { code: 'UNAUTHORIZED', message: 'Invalid credentials' } });
  }
}
