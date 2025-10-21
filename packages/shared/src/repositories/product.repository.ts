/**
 * Product Repository
 *
 * Database operations for products table
 */

import { Knex } from 'knex';
import { BaseRepository } from './base.repository';
import { Product } from '../entities/product.entity';

export class ProductRepository extends BaseRepository<Product> {
  constructor(db: Knex) {
    super(db, 'products');
  }

  async findLowStock(threshold: number = 10): Promise<Product[]> {
    const rows = await this.db(this.tableName)
      .where('stock_quantity', '<', threshold)
      .orderBy('stock_quantity', 'asc');
    return rows.map((row) => this.mapToEntity(row));
  }

  async findWithPagination(
    page: number = 1,
    limit: number = 20,
    sort: 'price_asc' | 'price_desc' | 'newest' = 'newest'
  ): Promise<{ products: Product[]; total: number }> {
    const offset = (page - 1) * limit;

    let orderByColumn = 'created_at';
    let orderByDirection: 'asc' | 'desc' = 'desc';

    if (sort === 'price_asc') {
      orderByColumn = 'price';
      orderByDirection = 'asc';
    } else if (sort === 'price_desc') {
      orderByColumn = 'price';
      orderByDirection = 'desc';
    }

    const [rows, [{ count }]] = await Promise.all([
      this.db(this.tableName)
        .select('*')
        .orderBy(orderByColumn, orderByDirection)
        .limit(limit)
        .offset(offset),
      this.db(this.tableName).count('* as count'),
    ]);

    return {
      products: rows.map((row) => this.mapToEntity(row)),
      total: Number(count),
    };
  }

  protected mapToEntity(row: any): Product {
    return {
      productId: row.product_id,
      name: row.name,
      description: row.description,
      price: parseFloat(row.price),
      stockQuantity: row.stock_quantity,
      createdAt: new Date(row.created_at),
      updatedAt: new Date(row.updated_at),
    };
  }
}
