/**
 * Migration: Create orders table
 *
 * This migration creates the orders table with foreign key to users.
 */

exports.up = function(knex) {
  return knex.schema.createTable('orders', function(table) {
    // Primary key
    table.uuid('order_id')
      .primary()
      .defaultTo(knex.raw('uuid_generate_v4()'));

    // Foreign key to users
    table.uuid('user_id').notNullable();
    table.foreign('user_id')
      .references('user_id')
      .inTable('users')
      .onDelete('CASCADE')
      .onUpdate('CASCADE');

    // Columns
    table.decimal('total_amount', 10, 2).notNullable();
    table.enum('status', ['pending', 'completed', 'cancelled'])
      .notNullable()
      .defaultTo('pending');

    // Timestamps
    table.timestamp('created_at').notNullable().defaultTo(knex.fn.now());
    table.timestamp('updated_at').notNullable().defaultTo(knex.fn.now());

    // Indexes
    table.index('user_id', 'orders_user_id_idx');
    table.index('status', 'orders_status_idx');
    table.index('created_at', 'orders_created_at_idx');

    // Constraints
    table.check('total_amount >= 0', null, 'orders_total_amount_check');
  });
};

exports.down = function(knex) {
  return knex.schema.dropTableIfExists('orders');
};
