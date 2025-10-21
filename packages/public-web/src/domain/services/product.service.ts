/**
 * Product Service
 *
 * Business logic for product operations
 */

import { getDbConnection, ProductRepository, Product } from '@sample-app/shared';

export class ProductService {
  async getProducts(
    page: number,
    limit: number,
    sort: 'price_asc' | 'price_desc' | 'newest'
  ): Promise<{ products: Product[]; total: number }> {
    const db = await getDbConnection();
    const productRepo = new ProductRepository(db);

    return productRepo.findWithPagination(page, limit, sort);
  }

  async getProductById(productId: string): Promise<Product | null> {
    const db = await getDbConnection();
    const productRepo = new ProductRepository(db);

    return productRepo.findById(productId, 'product_id');
  }
}
