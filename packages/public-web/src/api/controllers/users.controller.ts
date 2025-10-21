/**
 * Users Controller
 */

import { Request, Response, NextFunction } from 'express';
import { UserService } from '../../domain/services/user.service';
import { validator, ValidationError, logger } from '@sample-app/shared';

export class UsersController {
  private userService: UserService;

  constructor() {
    this.userService = new UserService();
  }

  async register(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
      const { email, name, password } = req.body;

      // Validation
      validator.validateEmail(email);
      validator.validateString(name, 'name', 1, 255);
      validator.validatePassword(password);

      const user = await this.userService.registerUser(email, name, password);

      logger.info('User registered successfully', { userId: user.userId, email });

      res.status(201).json({
        userId: user.userId,
        email: user.email,
        name: user.name,
        createdAt: user.createdAt.toISOString(),
      });
    } catch (error) {
      next(error);
    }
  }

  async login(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
      const { email, password } = req.body;

      // Validation
      validator.validateEmail(email);
      validator.validatePassword(password);

      const result = await this.userService.loginUser(email, password);

      logger.info('User logged in successfully', { email });

      res.status(200).json({
        token: result.token,
        expiresIn: result.expiresIn,
      });
    } catch (error) {
      next(error);
    }
  }
}
