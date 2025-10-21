/**
 * OrderItem Entity
 *
 * Represents an item within an order
 */

export interface OrderItem {
  orderItemId: string;
  orderId: string;
  productId: string;
  quantity: number;
  price: number;
}

export interface CreateOrderItemDto {
  orderId: string;
  productId: string;
  quantity: number;
  price: number;
}
