/**
 * User Entity
 *
 * Represents a user in the system
 */

export interface User {
  userId: string;
  email: string;
  name: string;
  createdAt: Date;
  updatedAt: Date;
}

export interface CreateUserDto {
  email: string;
  name: string;
  passwordHash: string;
}

export interface UpdateUserDto {
  email?: string;
  name?: string;
}
