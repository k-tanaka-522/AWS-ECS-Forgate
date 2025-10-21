/**
 * Orders Controller
 */

import { Request, Response, NextFunction } from 'express';
import { OrderService } from '../../domain/services/order.service';
import { validator, logger } from '@sample-app/shared';

export class OrdersController {
  private orderService: OrderService;

  constructor() {
    this.orderService = new OrderService();
  }

  async createOrder(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
      const userId = (req as any).user.userId;
      const { items } = req.body;

      if (!Array.isArray(items) || items.length === 0) {
        return res.status(400).json({
          error: {
            code: 'VALIDATION_ERROR',
            message: 'Items array is required and must not be empty',
          },
        });
      }

      // Validate each item
      for (const item of items) {
        validator.validateString(item.productId, 'productId');
        validator.validatePositiveNumber(item.quantity, 'quantity');
      }

      const order = await this.orderService.createOrder(userId, items);

      logger.info('Order created successfully', { orderId: order.orderId, userId });

      res.status(201).json(order);
    } catch (error) {
      next(error);
    }
  }

  async getOrderById(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
      const userId = (req as any).user.userId;
      const { orderId } = req.params;

      validator.validateString(orderId, 'orderId');

      const order = await this.orderService.getOrderById(orderId, userId);

      if (!order) {
        return res.status(404).json({
          error: {
            code: 'NOT_FOUND',
            message: 'Order not found',
          },
        });
      }

      res.status(200).json(order);
    } catch (error) {
      next(error);
    }
  }
}
