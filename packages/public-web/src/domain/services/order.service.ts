/**
 * Order Service
 *
 * Business logic for order operations
 */

import {
  getDbConnection,
  OrderRepository,
  OrderItemRepository,
  ProductRepository,
  Order,
} from '@sample-app/shared';

interface OrderItem {
  productId: string;
  quantity: number;
}

export class OrderService {
  async createOrder(userId: string, items: OrderItem[]): Promise<any> {
    const db = await getDbConnection();
    const orderRepo = new OrderRepository(db);
    const orderItemRepo = new OrderItemRepository(db);
    const productRepo = new ProductRepository(db);

    // Start transaction
    return db.transaction(async (trx) => {
      let totalAmount = 0;
      const orderItems = [];

      // Validate products and calculate total
      for (const item of items) {
        const product = await productRepo.findById(item.productId, 'product_id');

        if (!product) {
          throw new Error(`Product ${item.productId} not found`);
        }

        if (product.stockQuantity < item.quantity) {
          throw new Error(`Insufficient stock for product ${product.name}`);
        }

        totalAmount += product.price * item.quantity;
        orderItems.push({
          productId: product.productId,
          productName: product.name,
          quantity: item.quantity,
          price: product.price,
        });
      }

      // Create order
      const [order] = await trx('orders')
        .insert({
          user_id: userId,
          total_amount: totalAmount,
          status: 'pending',
        })
        .returning('*');

      // Create order items
      const createdItems = [];
      for (const item of orderItems) {
        const [orderItem] = await trx('order_items')
          .insert({
            order_id: order.order_id,
            product_id: item.productId,
            quantity: item.quantity,
            price: item.price,
          })
          .returning('*');

        createdItems.push({
          orderItemId: orderItem.order_item_id,
          productId: item.productId,
          productName: item.productName,
          quantity: item.quantity,
          price: parseFloat(item.price),
        });
      }

      return {
        orderId: order.order_id,
        userId: order.user_id,
        totalAmount: parseFloat(order.total_amount),
        status: order.status,
        items: createdItems,
        createdAt: new Date(order.created_at).toISOString(),
      };
    });
  }

  async getOrderById(orderId: string, userId: string): Promise<any | null> {
    const db = await getDbConnection();
    const orderRepo = new OrderRepository(db);
    const orderItemRepo = new OrderItemRepository(db);

    const order = await orderRepo.findById(orderId, 'order_id');

    if (!order || order.userId !== userId) {
      return null;
    }

    const items = await orderItemRepo.findByOrderIdWithProductDetails(orderId);

    return {
      orderId: order.orderId,
      userId: order.userId,
      totalAmount: order.totalAmount,
      status: order.status,
      items,
      createdAt: order.createdAt.toISOString(),
      updatedAt: order.updatedAt.toISOString(),
    };
  }
}
