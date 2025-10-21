/**
 * Order Repository
 *
 * Database operations for orders table
 */

import { Knex } from 'knex';
import { BaseRepository } from './base.repository';
import { Order, OrderStatus } from '../entities/order.entity';

export class OrderRepository extends BaseRepository<Order> {
  constructor(db: Knex) {
    super(db, 'orders');
  }

  async findByUserId(userId: string, limit: number = 20): Promise<Order[]> {
    const rows = await this.db(this.tableName)
      .where({ user_id: userId })
      .orderBy('created_at', 'desc')
      .limit(limit);
    return rows.map((row) => this.mapToEntity(row));
  }

  async findByStatus(status: OrderStatus, limit: number = 100): Promise<Order[]> {
    const rows = await this.db(this.tableName)
      .where({ status })
      .orderBy('created_at', 'desc')
      .limit(limit);
    return rows.map((row) => this.mapToEntity(row));
  }

  async findWithPagination(
    page: number = 1,
    limit: number = 20,
    status?: OrderStatus,
    userId?: string
  ): Promise<{ orders: Order[]; total: number }> {
    const offset = (page - 1) * limit;

    let query = this.db(this.tableName).select('*');

    if (status) {
      query = query.where({ status });
    }

    if (userId) {
      query = query.where({ user_id: userId });
    }

    const [rows, [{ count }]] = await Promise.all([
      query.orderBy('created_at', 'desc').limit(limit).offset(offset),
      this.db(this.tableName)
        .count('* as count')
        .modify((qb) => {
          if (status) qb.where({ status });
          if (userId) qb.where({ user_id: userId });
        }),
    ]);

    return {
      orders: rows.map((row) => this.mapToEntity(row)),
      total: Number(count),
    };
  }

  protected mapToEntity(row: any): Order {
    return {
      orderId: row.order_id,
      userId: row.user_id,
      totalAmount: parseFloat(row.total_amount),
      status: row.status as OrderStatus,
      createdAt: new Date(row.created_at),
      updatedAt: new Date(row.updated_at),
    };
  }
}
