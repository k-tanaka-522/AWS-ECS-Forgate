/**
 * Validator Utility
 *
 * Common validation functions
 */

export class ValidationError extends Error {
  public field: string;

  constructor(field: string, message: string) {
    super(message);
    this.name = 'ValidationError';
    this.field = field;
  }
}

export const validator = {
  isEmail(email: string): boolean {
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    return emailRegex.test(email);
  },

  isValidPassword(password: string): boolean {
    // At least 8 characters
    return password.length >= 8;
  },

  isPositiveNumber(value: number): boolean {
    return typeof value === 'number' && value > 0;
  },

  isNonNegativeNumber(value: number): boolean {
    return typeof value === 'number' && value >= 0;
  },

  isValidUUID(uuid: string): boolean {
    const uuidRegex = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
    return uuidRegex.test(uuid);
  },

  validateEmail(email: string, fieldName: string = 'email'): void {
    if (!email || typeof email !== 'string') {
      throw new ValidationError(fieldName, 'Email is required');
    }
    if (!this.isEmail(email)) {
      throw new ValidationError(fieldName, 'Invalid email format');
    }
  },

  validatePassword(password: string, fieldName: string = 'password'): void {
    if (!password || typeof password !== 'string') {
      throw new ValidationError(fieldName, 'Password is required');
    }
    if (!this.isValidPassword(password)) {
      throw new ValidationError(fieldName, 'Password must be at least 8 characters');
    }
  },

  validateString(value: string, fieldName: string, minLength: number = 1, maxLength: number = 255): void {
    if (!value || typeof value !== 'string') {
      throw new ValidationError(fieldName, `${fieldName} is required`);
    }
    if (value.length < minLength) {
      throw new ValidationError(fieldName, `${fieldName} must be at least ${minLength} characters`);
    }
    if (value.length > maxLength) {
      throw new ValidationError(fieldName, `${fieldName} must not exceed ${maxLength} characters`);
    }
  },

  validatePositiveNumber(value: number, fieldName: string): void {
    if (typeof value !== 'number' || !this.isPositiveNumber(value)) {
      throw new ValidationError(fieldName, `${fieldName} must be a positive number`);
    }
  },

  validateNonNegativeNumber(value: number, fieldName: string): void {
    if (typeof value !== 'number' || !this.isNonNegativeNumber(value)) {
      throw new ValidationError(fieldName, `${fieldName} must be a non-negative number`);
    }
  },
};
