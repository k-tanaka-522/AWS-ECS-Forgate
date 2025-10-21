import { getDbConnection, OrderRepository, OrderStatus } from '@sample-app/shared';

export class OrderAdminService {
  async getOrders(page: number, limit: number, status?: OrderStatus) {
    const db = await getDbConnection();
    const repo = new OrderRepository(db);
    return repo.findWithPagination(page, limit, status);
  }

  async updateOrderStatus(orderId: string, status: OrderStatus) {
    const db = await getDbConnection();
    const repo = new OrderRepository(db);
    return repo.update(orderId, { status }, 'order_id');
  }
}
