import { Request, Response, NextFunction } from 'express';
import { ProductAdminService } from '../../domain/services/product-admin.service';
import { validator } from '@sample-app/shared';

export class ProductsController {
  private service = new ProductAdminService();

  async createProduct(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
      const { name, description, price, stockQuantity } = req.body;
      validator.validateString(name, 'name');
      validator.validateString(description, 'description', 1, 1000);
      validator.validateNonNegativeNumber(price, 'price');
      validator.validateNonNegativeNumber(stockQuantity, 'stockQuantity');

      const product = await this.service.createProduct({ name, description, price, stockQuantity });
      res.status(201).json(product);
    } catch (error) {
      next(error);
    }
  }

  async updateProduct(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
      const { productId } = req.params;
      const product = await this.service.updateProduct(productId, req.body);
      product ? res.status(200).json(product) : res.status(404).json({ error: 'Not found' });
    } catch (error) {
      next(error);
    }
  }

  async deleteProduct(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
      const { productId } = req.params;
      await this.service.deleteProduct(productId);
      res.status(204).send();
    } catch (error) {
      next(error);
    }
  }
}
