/**
 * Order Entity
 *
 * Represents an order placed by a user
 */

export type OrderStatus = 'pending' | 'completed' | 'cancelled';

export interface Order {
  orderId: string;
  userId: string;
  totalAmount: number;
  status: OrderStatus;
  createdAt: Date;
  updatedAt: Date;
}

export interface CreateOrderDto {
  userId: string;
  totalAmount: number;
  status: OrderStatus;
}

export interface UpdateOrderDto {
  status?: OrderStatus;
  totalAmount?: number;
}
