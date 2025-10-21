import { Router } from 'express';
import { OrdersController } from '../controllers/orders.controller';

export const ordersRouter = Router();
const controller = new OrdersController();

ordersRouter.get('/', controller.getOrders.bind(controller));
productsRouter.patch('/:orderId/status', controller.updateOrderStatus.bind(controller));
