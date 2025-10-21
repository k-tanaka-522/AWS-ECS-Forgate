/**
 * Migration: Create order_items table
 *
 * This migration creates the order_items table with foreign keys to orders and products.
 */

exports.up = function(knex) {
  return knex.schema.createTable('order_items', function(table) {
    // Primary key
    table.uuid('order_item_id')
      .primary()
      .defaultTo(knex.raw('uuid_generate_v4()'));

    // Foreign key to orders
    table.uuid('order_id').notNullable();
    table.foreign('order_id')
      .references('order_id')
      .inTable('orders')
      .onDelete('CASCADE')
      .onUpdate('CASCADE');

    // Foreign key to products
    table.uuid('product_id').notNullable();
    table.foreign('product_id')
      .references('product_id')
      .inTable('products')
      .onDelete('RESTRICT')
      .onUpdate('CASCADE');

    // Columns
    table.integer('quantity').notNullable();
    table.decimal('price', 10, 2).notNullable();

    // Indexes
    table.index('order_id', 'order_items_order_id_idx');
    table.index('product_id', 'order_items_product_id_idx');

    // Constraints
    table.check('quantity > 0', null, 'order_items_quantity_check');
    table.check('price >= 0', null, 'order_items_price_check');
  });
};

exports.down = function(knex) {
  return knex.schema.dropTableIfExists('order_items');
};
