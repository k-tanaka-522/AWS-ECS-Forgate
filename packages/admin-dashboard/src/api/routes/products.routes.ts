import { Router } from 'express';
import { ProductsController } from '../controllers/products.controller';

export const productsRouter = Router();
const controller = new ProductsController();

productsRouter.post('/', controller.createProduct.bind(controller));
productsRouter.put('/:productId', controller.updateProduct.bind(controller));
productsRouter.delete('/:productId', controller.deleteProduct.bind(controller));
