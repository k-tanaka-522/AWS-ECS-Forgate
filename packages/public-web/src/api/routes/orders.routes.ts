/**
 * Orders Routes
 */

import { Router } from 'express';
import { OrdersController } from '../controllers/orders.controller';
import { authMiddleware } from '../middleware/auth.middleware';

export const ordersRouter = Router();
const controller = new OrdersController();

// All order endpoints require authentication
ordersRouter.use(authMiddleware);

ordersRouter.post('/', controller.createOrder.bind(controller));
ordersRouter.get('/:orderId', controller.getOrderById.bind(controller));
