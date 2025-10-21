import { getDbConnection, ProductRepository, CreateProductDto, UpdateProductDto, Product } from '@sample-app/shared';

export class ProductAdminService {
  async createProduct(dto: CreateProductDto): Promise<Product> {
    const db = await getDbConnection();
    const repo = new ProductRepository(db);
    return repo.create(dto);
  }

  async updateProduct(productId: string, dto: UpdateProductDto): Promise<Product | null> {
    const db = await getDbConnection();
    const repo = new ProductRepository(db);
    return repo.update(productId, dto, 'product_id');
  }

  async deleteProduct(productId: string): Promise<void> {
    const db = await getDbConnection();
    const repo = new ProductRepository(db);
    await repo.delete(productId, 'product_id');
  }
}
