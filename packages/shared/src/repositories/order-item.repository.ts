/**
 * OrderItem Repository
 *
 * Database operations for order_items table
 */

import { Knex } from 'knex';
import { BaseRepository } from './base.repository';
import { OrderItem } from '../entities/order-item.entity';

export class OrderItemRepository extends BaseRepository<OrderItem> {
  constructor(db: Knex) {
    super(db, 'order_items');
  }

  async findByOrderId(orderId: string): Promise<OrderItem[]> {
    const rows = await this.db(this.tableName).where({ order_id: orderId });
    return rows.map((row) => this.mapToEntity(row));
  }

  async findByOrderIdWithProductDetails(orderId: string): Promise<any[]> {
    const rows = await this.db(this.tableName)
      .join('products', 'order_items.product_id', 'products.product_id')
      .where('order_items.order_id', orderId)
      .select(
        'order_items.*',
        'products.name as product_name',
        'products.description as product_description'
      );

    return rows.map((row) => ({
      orderItemId: row.order_item_id,
      orderId: row.order_id,
      productId: row.product_id,
      productName: row.product_name,
      productDescription: row.product_description,
      quantity: row.quantity,
      price: parseFloat(row.price),
    }));
  }

  protected mapToEntity(row: any): OrderItem {
    return {
      orderItemId: row.order_item_id,
      orderId: row.order_id,
      productId: row.product_id,
      quantity: row.quantity,
      price: parseFloat(row.price),
    };
  }
}
