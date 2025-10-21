/**
 * User Repository
 *
 * Database operations for users table
 */

import { Knex } from 'knex';
import { BaseRepository } from './base.repository';
import { User, CreateUserDto } from '../entities/user.entity';

export class UserRepository extends BaseRepository<User> {
  constructor(db: Knex) {
    super(db, 'users');
  }

  async findByEmail(email: string): Promise<User | null> {
    const row = await this.db(this.tableName).where({ email }).first();
    return row ? this.mapToEntity(row) : null;
  }

  async createUser(dto: CreateUserDto): Promise<User> {
    const [row] = await this.db(this.tableName)
      .insert({
        email: dto.email,
        name: dto.name,
        password_hash: dto.passwordHash,
      })
      .returning('*');
    return this.mapToEntity(row);
  }

  async findByIdWithPassword(userId: string): Promise<any | null> {
    const row = await this.db(this.tableName)
      .where({ user_id: userId })
      .select('*')
      .first();
    return row || null;
  }

  protected mapToEntity(row: any): User {
    return {
      userId: row.user_id,
      email: row.email,
      name: row.name,
      createdAt: new Date(row.created_at),
      updatedAt: new Date(row.updated_at),
    };
  }
}
