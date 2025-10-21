/**
 * User Service
 *
 * Business logic for user operations
 */

import bcrypt from 'bcrypt';
import jwt from 'jsonwebtoken';
import { getDbConnection, UserRepository, User } from '@sample-app/shared';

export class UserService {
  async registerUser(email: string, name: string, password: string): Promise<User> {
    const db = await getDbConnection();
    const userRepo = new UserRepository(db);

    // Check if user already exists
    const existing = await userRepo.findByEmail(email);
    if (existing) {
      throw new Error('User with this email already exists');
    }

    // Hash password
    const passwordHash = await bcrypt.hash(password, 10);

    // Create user
    const user = await userRepo.createUser({
      email,
      name,
      passwordHash,
    });

    return user;
  }

  async loginUser(email: string, password: string): Promise<{ token: string; expiresIn: number }> {
    const db = await getDbConnection();
    const userRepo = new UserRepository(db);

    // Find user with password
    const user = await userRepo.findByIdWithPassword(
      (await userRepo.findByEmail(email))?.userId || ''
    );

    if (!user) {
      throw new Error('Invalid credentials');
    }

    // Verify password
    const isValid = await bcrypt.compare(password, user.password_hash);
    if (!isValid) {
      throw new Error('Invalid credentials');
    }

    // Generate JWT
    const jwtSecret = process.env.JWT_SECRET || 'development-secret-change-in-production';
    const expiresIn = 86400; // 24 hours

    const token = jwt.sign(
      {
        userId: user.user_id,
        email: user.email,
      },
      jwtSecret,
      { expiresIn }
    );

    return { token, expiresIn };
  }
}
