/**
 * Migration: Create products table
 *
 * This migration creates the products table for managing product catalog.
 */

exports.up = function(knex) {
  return knex.schema.createTable('products', function(table) {
    // Primary key
    table.uuid('product_id')
      .primary()
      .defaultTo(knex.raw('uuid_generate_v4()'));

    // Columns
    table.string('name', 255).notNullable();
    table.text('description').notNullable();
    table.decimal('price', 10, 2).notNullable();
    table.integer('stock_quantity').notNullable().defaultTo(0);

    // Timestamps
    table.timestamp('created_at').notNullable().defaultTo(knex.fn.now());
    table.timestamp('updated_at').notNullable().defaultTo(knex.fn.now());

    // Indexes
    table.index('name', 'products_name_idx');
    table.index('price', 'products_price_idx');
    table.index('stock_quantity', 'products_stock_quantity_idx');
    table.index('created_at', 'products_created_at_idx');

    // Constraints
    table.check('price >= 0', null, 'products_price_check');
    table.check('stock_quantity >= 0', null, 'products_stock_quantity_check');
  });
};

exports.down = function(knex) {
  return knex.schema.dropTableIfExists('products');
};
