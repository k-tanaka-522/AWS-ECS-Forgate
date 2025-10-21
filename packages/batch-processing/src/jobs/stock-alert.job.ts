/**
 * Stock Alert Batch Job
 * Runs daily at 9:00 JST to check low stock products
 */

import { getDbConnection, ProductRepository, logger } from '@sample-app/shared';

async function runStockAlert(): Promise<void> {
  const db = await getDbConnection();

  try {
    logger.info('Starting stock alert job...');

    const productRepo = new ProductRepository(db);
    const lowStockProducts = await productRepo.findLowStock(10);

    if (lowStockProducts.length === 0) {
      logger.info('No low stock products found.');
      return;
    }

    logger.warn(`Found ${lowStockProducts.length} low stock products:`, {
      products: lowStockProducts.map((p) => ({
        productId: p.productId,
        name: p.name,
        stockQuantity: p.stockQuantity,
      })),
    });

    logger.info('Stock alert job completed.');
  } catch (error) {
    logger.error('Stock alert job failed:', error);
    throw error;
  } finally {
    await db.destroy();
  }
}

if (require.main === module) {
  runStockAlert()
    .then(() => process.exit(0))
    .catch((error) => {
      logger.error('Fatal error:', error);
      process.exit(1);
    });
}

export { runStockAlert };
