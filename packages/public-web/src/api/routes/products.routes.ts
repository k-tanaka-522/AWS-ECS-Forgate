/**
 * Products Routes
 */

import { Router } from 'express';
import { ProductsController } from '../controllers/products.controller';

export const productsRouter = Router();
const controller = new ProductsController();

// Public product endpoints
productsRouter.get('/', controller.getProducts.bind(controller));
productsRouter.get('/:productId', controller.getProductById.bind(controller));
