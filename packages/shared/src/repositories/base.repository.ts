/**
 * Base Repository
 *
 * Abstract base class for all repositories
 * Provides common CRUD operations
 */

import { Knex } from 'knex';

export abstract class BaseRepository<T> {
  protected db: Knex;
  protected tableName: string;

  constructor(db: Knex, tableName: string) {
    this.db = db;
    this.tableName = tableName;
  }

  async findById(id: string, idColumn: string = 'id'): Promise<T | null> {
    const row = await this.db(this.tableName).where(idColumn, id).first();
    return row ? this.mapToEntity(row) : null;
  }

  async findAll(limit: number = 100, offset: number = 0): Promise<T[]> {
    const rows = await this.db(this.tableName).limit(limit).offset(offset);
    return rows.map((row) => this.mapToEntity(row));
  }

  async create(data: Partial<any>): Promise<T> {
    const [row] = await this.db(this.tableName).insert(data).returning('*');
    return this.mapToEntity(row);
  }

  async update(id: string, data: Partial<any>, idColumn: string = 'id'): Promise<T | null> {
    const [row] = await this.db(this.tableName)
      .where(idColumn, id)
      .update({ ...data, updated_at: this.db.fn.now() })
      .returning('*');
    return row ? this.mapToEntity(row) : null;
  }

  async delete(id: string, idColumn: string = 'id'): Promise<boolean> {
    const result = await this.db(this.tableName).where(idColumn, id).del();
    return result > 0;
  }

  protected abstract mapToEntity(row: any): T;
}
