/**
 * Migration: Create users table
 *
 * This migration creates the users table with UUID primary key,
 * email uniqueness constraint, and necessary indexes.
 */

exports.up = function(knex) {
  return knex.schema
    .raw('CREATE EXTENSION IF NOT EXISTS "uuid-ossp"')
    .then(() => {
      return knex.schema.createTable('users', function(table) {
        // Primary key
        table.uuid('user_id')
          .primary()
          .defaultTo(knex.raw('uuid_generate_v4()'));

        // Columns
        table.string('email', 255).notNullable().unique();
        table.string('name', 255).notNullable();
        table.string('password_hash', 255).notNullable();

        // Timestamps
        table.timestamp('created_at').notNullable().defaultTo(knex.fn.now());
        table.timestamp('updated_at').notNullable().defaultTo(knex.fn.now());

        // Indexes
        table.index('email', 'users_email_idx');
        table.index('created_at', 'users_created_at_idx');
      });
    });
};

exports.down = function(knex) {
  return knex.schema.dropTableIfExists('users');
};
