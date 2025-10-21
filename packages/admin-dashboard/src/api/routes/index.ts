/**
 * Admin API Routes
 */

import { Router } from 'express';
import { authMiddleware } from '../middleware/auth.middleware';
import { productsRouter } from './products.routes';
import { ordersRouter } from './orders.routes';

export const router = Router();

router.use(authMiddleware);
router.use('/products', productsRouter);
router.use('/orders', ordersRouter);
