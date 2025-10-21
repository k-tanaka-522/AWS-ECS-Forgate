/**
 * Product Entity
 *
 * Represents a product in the catalog
 */

export interface Product {
  productId: string;
  name: string;
  description: string;
  price: number;
  stockQuantity: number;
  createdAt: Date;
  updatedAt: Date;
}

export interface CreateProductDto {
  name: string;
  description: string;
  price: number;
  stockQuantity: number;
}

export interface UpdateProductDto {
  name?: string;
  description?: string;
  price?: number;
  stockQuantity?: number;
}
