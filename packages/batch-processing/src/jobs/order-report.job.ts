/**
 * Order Report Batch Job
 * Runs weekly on Monday at 10:00 JST to generate order statistics
 */

import { getDbConnection, logger } from '@sample-app/shared';

async function runOrderReport(): Promise<void> {
  const db = await getDbConnection();

  try {
    logger.info('Starting order report job...');

    const sevenDaysAgo = new Date();
    sevenDaysAgo.setDate(sevenDaysAgo.getDate() - 7);

    // Total orders and revenue
    const [orderSummary] = await db('orders')
      .where('created_at', '>=', sevenDaysAgo)
      .count('order_id as totalOrders')
      .sum('total_amount as totalRevenue');

    const totalOrders = Number(orderSummary.totalOrders);
    const totalRevenue = Number(orderSummary.totalRevenue) || 0;
    const averageOrderValue = totalOrders > 0 ? totalRevenue / totalOrders : 0;

    // Top products
    const topProducts = await db('order_items as oi')
      .join('orders as o', 'oi.order_id', 'o.order_id')
      .join('products as p', 'oi.product_id', 'p.product_id')
      .where('o.created_at', '>=', sevenDaysAgo)
      .groupBy('p.product_id', 'p.name')
      .select(
        'p.product_id as productId',
        'p.name as productName',
        db.raw('SUM(oi.quantity) as totalQuantity'),
        db.raw('SUM(oi.price * oi.quantity) as totalRevenue')
      )
      .orderBy('totalRevenue', 'desc')
      .limit(5);

    const stats = {
      totalOrders,
      totalRevenue,
      averageOrderValue,
      topProducts,
    };

    logger.info('Order report (last 7 days):', stats);

    logger.info('Order report job completed.');
  } catch (error) {
    logger.error('Order report job failed:', error);
    throw error;
  } finally {
    await db.destroy();
  }
}

if (require.main === module) {
  runOrderReport()
    .then(() => process.exit(0))
    .catch((error) => {
      logger.error('Fatal error:', error);
      process.exit(1);
    });
}

export { runOrderReport };
