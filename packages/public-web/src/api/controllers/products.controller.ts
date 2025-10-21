/**
 * Products Controller
 */

import { Request, Response, NextFunction } from 'express';
import { ProductService } from '../../domain/services/product.service';
import { validator } from '@sample-app/shared';

export class ProductsController {
  private productService: ProductService;

  constructor() {
    this.productService = new ProductService();
  }

  async getProducts(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
      const page = parseInt(req.query.page as string) || 1;
      const limit = Math.min(parseInt(req.query.limit as string) || 20, 100);
      const sort = (req.query.sort as string) || 'newest';

      if (!['price_asc', 'price_desc', 'newest'].includes(sort)) {
        return res.status(400).json({
          error: {
            code: 'VALIDATION_ERROR',
            message: 'Invalid sort parameter',
          },
        });
      }

      const result = await this.productService.getProducts(page, limit, sort as any);

      res.status(200).json({
        products: result.products.map((p) => ({
          productId: p.productId,
          name: p.name,
          description: p.description,
          price: p.price,
          stockQuantity: p.stockQuantity,
        })),
        pagination: {
          currentPage: page,
          totalPages: Math.ceil(result.total / limit),
          totalItems: result.total,
        },
      });
    } catch (error) {
      next(error);
    }
  }

  async getProductById(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
      const { productId } = req.params;

      validator.validateString(productId, 'productId');

      const product = await this.productService.getProductById(productId);

      if (!product) {
        return res.status(404).json({
          error: {
            code: 'NOT_FOUND',
            message: 'Product not found',
          },
        });
      }

      res.status(200).json({
        productId: product.productId,
        name: product.name,
        description: product.description,
        price: product.price,
        stockQuantity: product.stockQuantity,
        createdAt: product.createdAt.toISOString(),
        updatedAt: product.updatedAt.toISOString(),
      });
    } catch (error) {
      next(error);
    }
  }
}
