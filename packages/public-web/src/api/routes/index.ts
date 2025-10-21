/**
 * API Routes - Root Router
 */

import { Router } from 'express';
import { usersRouter } from './users.routes';
import { productsRouter } from './products.routes';
import { ordersRouter } from './orders.routes';

export const router = Router();

router.use('/users', usersRouter);
router.use('/products', productsRouter);
router.use('/orders', ordersRouter);
