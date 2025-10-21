import { Request, Response, NextFunction } from 'express';
import { OrderAdminService } from '../../domain/services/order-admin.service';

export class OrdersController {
  private service = new OrderAdminService();

  async getOrders(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
      const page = parseInt(req.query.page as string) || 1;
      const limit = Math.min(parseInt(req.query.limit as string) || 20, 100);
      const status = req.query.status as string;

      const result = await this.service.getOrders(page, limit, status as any);
      res.status(200).json(result);
    } catch (error) {
      next(error);
    }
  }

  async updateOrderStatus(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
      const { orderId } = req.params;
      const { status } = req.body;
      const order = await this.service.updateOrderStatus(orderId, status);
      res.status(200).json(order);
    } catch (error) {
      next(error);
    }
  }
}
